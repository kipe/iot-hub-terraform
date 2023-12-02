# Define the number of IoT devices to create
variable "scaleway_iot_device_count" {
  type = number
  default = 1
}
# Create the IoT Hub instance
resource "scaleway_iot_hub" "iot-hub" {
  name = "iot-hub"
  product_plan = "plan_shared"
}
# Download the certificate
# see: https://github.com/scaleway/terraform-provider-scaleway/issues/2264
data "http" "iot-hub-ca" {
  url = "https://iot.s3.nl-ams.scw.cloud/certificates/${scaleway_iot_hub.iot-hub.region}/iot-hub-ca.pem"
}
# Create the IoT devices
resource "scaleway_iot_device" "iot-device" {
  count = var.scaleway_iot_device_count
  hub_id = scaleway_iot_hub.iot-hub.id
  name = "test-device-${count.index + 1}"
}
# Create a route from topic "temperature/#", storing the values to database
resource "scaleway_iot_route" "route" {
  hub_id = scaleway_iot_hub.iot-hub.id
  name = "device-temperatures"
  topic = "temperature/#"
  database {
    query = "INSERT INTO temperature (device_id, temperature, timestamp) VALUES (split_part($TOPIC,'/',3), CAST(TRIM($PAYLOAD) AS NUMERIC(5, 2)), NOW())"
    host = scaleway_rdb_instance.database.endpoint_ip
    port = scaleway_rdb_instance.database.endpoint_port
    dbname = scaleway_rdb_database.main.name
    username = scaleway_rdb_user.main.name
    password = scaleway_rdb_user.main.password
  }
}
# Create configuration file for the IoT devices
resource "local_file" "iot-device-configuration" {
  count = var.scaleway_iot_device_count
  filename = "${path.root}/../device-configs/device-${count.index + 1}.env"
  content = <<EOT
MQTT_HOST="${scaleway_iot_hub.iot-hub.endpoint}"
DEVICE_ID="${scaleway_iot_device.iot-device[count.index].id}"
CERT="${scaleway_iot_device.iot-device[count.index].certificate[0].crt}"
KEY="${scaleway_iot_device.iot-device[count.index].certificate[0].key}"
CA="${data.http.iot-hub-ca.response_body}"
  EOT
  directory_permission = 0700
  file_permission = 0400
}
