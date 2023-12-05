# Scaleway IoT Hub - Terraform

This is a hobby project I used to test the capabilities of IoT Hub by Scaleway and setting it up using Terraform.

This is in no way designed to be secure, so don't use directly, just for inspiration.

Setups the following services:

- IoT Hub for handling configurable number of devices
- Document DB (FerretDB) to store measurements coming from the devices
- Serverless Function to ingest data coming in through MQTT from the devices and serve it out via REST
