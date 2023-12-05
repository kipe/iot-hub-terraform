# Define the number of IoT devices to create
variable "scaleway_iot_device_count" {
  type    = number
  default = 1
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
  name   = "test-device-${count.index + 1}"
}
resource "scaleway_iot_route" "measurement-function" {
  hub_id = scaleway_iot_hub.iot-hub.id
  name   = "device-temperatures"
  topic  = "temperature/#"
  rest {
    verb    = "post"
    uri     = "https://${scaleway_function.measurement.domain_name}"
    headers = {}
  }
}
# Create configuration file for the IoT devices
resource "local_sensitive_file" "iot-device-configuration" {
  count                = var.scaleway_iot_device_count
  filename             = "${path.root}/../device-configs/device-${count.index + 1}.env"
  content              = <<EOT
MQTT_HOST="${scaleway_iot_hub.iot-hub.endpoint}"
DEVICE_ID="${scaleway_iot_device.iot-device[count.index].id}"
CERT="${scaleway_iot_device.iot-device[count.index].certificate[0].crt}"
KEY="${scaleway_iot_device.iot-device[count.index].certificate[0].key}"
CA="${data.http.iot-hub-ca.response_body}"
  EOT
  directory_permission = 0700
  file_permission      = 0600
}
