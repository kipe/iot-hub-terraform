#!/usr/bin/env python3
import os
import logging
from paho.mqtt.client import Client
from decouple import Config, RepositoryEnv

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)


if __name__ == '__main__':
    # Unfortunately the IoT Hub CA still needs to be downloaded from the web UI
    # see: https://github.com/scaleway/terraform-provider-scaleway/issues/2264
    if not os.path.exists('./device-configs/iot-hub-ca.pem'):
        raise ValueError(
            'You need to manually download IoT Hub CA from the web ui '
            'and store it to "./device-configs/iot-hub-ca.pem"'
        )
    # Loop over the devices, found based on the environment
    # configuration existing
    for i, device_name in enumerate([
        config_file.rstrip('.env')
        for config_file in filter(
            lambda x: x.endswith('.env'),
            os.listdir('./device-configs'),
        )
    ]):
        # Load the configuration variables from the files
        config = Config(RepositoryEnv(f'./device-configs/{device_name}.env'))
        MQTT_HOST = config.get('MQTT_HOST', cast=str)
        DEVICE_ID = config.get('DEVICE_ID', cast=str)
        # Initialize MQTT client
        mqttc = Client()
        mqttc.enable_logger(logger)
        # Set the certificates to use
        mqttc.tls_set(
            ca_certs='./device-configs/iot-hub-ca.pem',
            certfile=f'./device-configs/{device_name}.crt',
            keyfile=f'./device-configs/{device_name}.key',
        )
        # Connect to the MQTT broker.
        # Port 8883 is hardcoded as it's default for the Scaleway MQTTS.
        mqttc.connect(MQTT_HOST, port=8883)
        # Start the MQTT-loop
        mqttc.loop_start()
        # Publish a (very fake) temperature value
        mqttc.publish(f'temperature/{DEVICE_ID}', f"{22.0 + i}")
        # Disconnect from MQTT
        mqttc.disconnect()
        # Stop the loop
        mqttc.loop_stop()
