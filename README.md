# Scaleway IoT Hub - Terraform
This is a hobby project I used to test the capabilities of IoT Hub by Scaleway and setting it up using Terraform.

This is in no way designed to be secure, so don't use directly, just for inspiration.

## Accessing database
```sh
PGPASSWORD=`terraform output -raw database_password` \
psql -h `terraform output -raw database_ip` \
      -p `terraform output -raw database_port` \
      -U `terraform output -raw database_user` \
      -d `terraform output -raw database_name`
```
