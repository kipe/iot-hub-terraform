# Define the number of IoT devices to create
variable "scaleway_iot_device_count" {
  type    = number
  default = 1
}
# Define device names
resource "random_uuid" "device-name" {
  count = var.scaleway_iot_device_count
}
# Create the IoT Hub instance
resource "scaleway_iot_hub" "iot-hub" {
  name         = "iot-hub"
  product_plan = "plan_shared"
}
# Download the certificate
# see: https://github.com/scaleway/terraform-provider-scaleway/issues/2264
data "http" "iot-hub-ca" {
  url = "https://iot.s3.nl-ams.scw.cloud/certificates/${scaleway_iot_hub.iot-hub.region}/iot-hub-ca.pem"
}
# Create the IoT devices
resource "scaleway_iot_device" "iot-device" {
  count  = var.scaleway_iot_device_count
  hub_id = scaleway_iot_hub.iot-hub.id
  name   = random_uuid.device-name[count.index].id
  message_filters {
    publish {
      policy = "accept"
      topics = ["device/${random_uuid.device-name[count.index].id}"]
    }
    subscribe {
      policy = "accept"
      topics = ["configure/${random_uuid.device-name[count.index].id}"]
    }
  }
}
# Create a route from topic "device/#", upserting latest measurements for devices
resource "scaleway_iot_route" "measurement" {
  hub_id = scaleway_iot_hub.iot-hub.id
  name   = "device"
  topic  = "device/#"
  database {
    query    = <<-EOT
      WITH device_row AS (
        INSERT INTO device (device, last_seen, last_message)
        VALUES (split_part($TOPIC,'/',2), to_timestamp(($PAYLOAD::jsonb->>'time')::text, 'YYYY-MM-DD\THH:MI:SS:USTZH:TZM'::text), $PAYLOAD::jsonb)
        ON CONFLICT (device) DO UPDATE
          SET last_seen = excluded.last_seen,
              last_message = excluded.last_message
        RETURNING *
      ), temperature_insert AS (
        INSERT INTO temperature (time, device_id, temperature, labels)
        VALUES (
          (SELECT last_seen FROM device_row),
          (SELECT id FROM device_row),
          (SELECT CAST(last_message::jsonb->'temperature'->'value' AS NUMERIC(5, 2)) FROM device_row),
          (SELECT last_message::jsonb->'temperature'->'labels' FROM device_row)
        )
      )
      INSERT INTO cpu_usage (time, device_id, cpu_usage, labels)
      VALUES (
        (SELECT last_seen FROM device_row),
        (SELECT id FROM device_row),
        (SELECT CAST(last_message::jsonb->'cpu_usage'->'value' AS NUMERIC(5, 2)) FROM device_row),
        (SELECT last_message::jsonb->'cpu_usage'->'labels' FROM device_row)
      );
    EOT
    host     = scaleway_rdb_instance.database.endpoint_ip
    port     = scaleway_rdb_instance.database.endpoint_port
    dbname   = scaleway_rdb_database.main.name
    username = scaleway_rdb_user.main.name
    password = scaleway_rdb_user.main.password
  }
  depends_on = [scaleway_rdb_database.main, scaleway_rdb_user.main, scaleway_rdb_privilege.main, null_resource.create_tables]
}
# Create configuration file for the IoT devices
resource "local_file" "iot-device-configuration" {
  count                = var.scaleway_iot_device_count
  filename             = "${path.root}/../device-configs/device-${random_uuid.device-name[count.index].id}.env"
  content              = <<EOT
MQTT_HOST="${scaleway_iot_hub.iot-hub.endpoint}"
DEVICE_ID="${random_uuid.device-name[count.index].id}"
CERT="${scaleway_iot_device.iot-device[count.index].certificate[0].crt}"
KEY="${scaleway_iot_device.iot-device[count.index].certificate[0].key}"
CA="${data.http.iot-hub-ca.response_body}"
  EOT
  directory_permission = 0700
  file_permission      = 0600
}
