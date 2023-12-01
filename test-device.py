#!/usr/bin/env python3
import os
import logging
from paho.mqtt.client import Client
from decouple import Config, RepositoryEnv

logging.basicConfig(level=logging.DEBUG)


if __name__ == '__main__':
    if not os.path.exists('./device-configs/iot-hub-ca.pem'):
        raise ValueError(
            'You need to manually download IoT Hub CA from the web ui '
            'and store it to "./device-configs/iot-hub-ca.pem"'
        )

    for i, device_name in enumerate([
        config_file.rstrip('.env')
        for config_file in filter(
            lambda x: x.endswith('.env'),
            os.listdir('./device-configs'),
        )
    ]):
        config = Config(RepositoryEnv(f'./device-configs/{device_name}.env'))
        MQTT_HOST = config.get('MQTT_HOST', cast=str)
        DEVICE_ID = config.get('DEVICE_ID', cast=str)

        logger = logging.getLogger(__name__)
        mqttc = Client()
        mqttc.enable_logger(logger)
        mqttc.tls_set(
            ca_certs='./device-configs/iot-hub-ca.pem',
            certfile=f'./device-configs/{device_name}.crt',
            keyfile=f'./device-configs/{device_name}.key',
        )
        mqttc.connect(MQTT_HOST, port=8883)

        mqttc.loop_start()
        mqttc.publish(f'temperature/{DEVICE_ID}', f"{22.0 + i}")
        mqttc.disconnect()
        mqttc.loop_stop()
