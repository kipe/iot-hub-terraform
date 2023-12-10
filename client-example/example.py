#!/usr/bin/env python3
import os
import logging
import tempfile
from pathlib import Path
from paho.mqtt.client import Client
from dotenv import dotenv_values

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

CLIENT_CONFIG_PATH = Path(__file__, "..", "..", "device-configs").resolve()


def read_temperature() -> float:
    temperature = 0.0
    with open("/sys/class/thermal/thermal_zone0/temp", "r") as f_handle:
        temperature = float(f_handle.read().strip()) / 1000.0
    return temperature


def load_device_configuration(device_name: str) -> dict:
    # Load the configuration variables from the files
    return dotenv_values(CLIENT_CONFIG_PATH / f"{device_name}.env")


def set_mqtt_certificates(mqttc: Client, config: dict):
    # Create temporary files for certificates
    with tempfile.NamedTemporaryFile(mode="w", delete_on_close=False) as cert_file:
        cert_file.write(config["CERT"])
        cert_file.close()
        with tempfile.NamedTemporaryFile(mode="w", delete_on_close=False) as key_file:
            key_file.write(config["KEY"])
            key_file.close()
            with tempfile.NamedTemporaryFile(
                mode="w", delete_on_close=False
            ) as ca_file:
                ca_file.write(config["CA"])
                ca_file.close()
                # Set the certificates to use
                mqttc.tls_set(
                    ca_certs=ca_file.name,
                    certfile=cert_file.name,
                    keyfile=key_file.name,
                )


if __name__ == "__main__":
    # Loop over the devices, found based on the environment
    # configuration existing
    for i, device_name in enumerate(
        [
            config_file.rstrip(".env")
            for config_file in filter(
                lambda x: x.endswith(".env"),
                os.listdir(CLIENT_CONFIG_PATH),
            )
        ]
    ):
        # Load the configuration variables from the files
        config = load_device_configuration(device_name)
        # Initialize MQTT client
        mqttc = Client()
        mqttc.enable_logger(logger)
        # Set MQTT certificates
        set_mqtt_certificates(mqttc, config)
        # Connect to the MQTT broker.
        # Port 8883 is hardcoded as it's default for the Scaleway MQTTS.
        mqttc.connect(config["MQTT_HOST"], port=8883)
        # Start the MQTT-loop
        mqttc.loop_start()
        # Publish a temperature value read from the PC
        temperature = read_temperature()
        mqttc.publish(f"temperature/{config['DEVICE_ID']}", f"{temperature + i:.2f}")
        # Disconnect from MQTT
        mqttc.disconnect()
        # Stop the loop
        mqttc.loop_stop()
