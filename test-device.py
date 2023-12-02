#!/usr/bin/env python3
import os
import logging
import tempfile
from paho.mqtt.client import Client
from dotenv import dotenv_values

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)


if __name__ == "__main__":
    # Loop over the devices, found based on the environment
    # configuration existing
    for i, device_name in enumerate(
        [
            config_file.rstrip(".env")
            for config_file in filter(
                lambda x: x.endswith(".env"),
                os.listdir("./device-configs"),
            )
        ]
    ):
        # Load the configuration variables from the files
        config = dotenv_values(f"./device-configs/{device_name}.env")
        # Initialize MQTT client
        mqttc = Client()
        mqttc.enable_logger(logger)
        # Create temporary files for certificates
        with tempfile.NamedTemporaryFile(mode="w", delete_on_close=False) as cert_file:
            cert_file.write(config["CERT"])
            cert_file.close()
            with tempfile.NamedTemporaryFile(
                mode="w", delete_on_close=False
            ) as key_file:
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
        # Connect to the MQTT broker.
        # Port 8883 is hardcoded as it's default for the Scaleway MQTTS.
        mqttc.connect(config["MQTT_HOST"], port=8883)
        # Start the MQTT-loop
        mqttc.loop_start()
        # Publish a (very fake) temperature value
        mqttc.publish(f"temperature/{config['DEVICE_ID']}", f"{22.0 + i}")
        # Disconnect from MQTT
        mqttc.disconnect()
        # Stop the loop
        mqttc.loop_stop()
