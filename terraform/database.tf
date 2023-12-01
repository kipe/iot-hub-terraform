# Create a random string to use as the database user
resource "random_string" "database_user" {
  length = 12
  numeric = false
  special = false
}
# Create random password for database
resource "random_password" "database_password" {
  length = 16
  special = true
}
# Create the database instance
resource "scaleway_rdb_instance" "database" {
  name = "database"
  node_type = "DB-DEV-S"
  engine = "PostgreSQL-15"
  is_ha_cluster = false
  disable_backup = true
  # Unfortunately we have to keep the public endpoint as
  # we need it for provisioning and
  # IoT Hub -instance cannot be attached to a private network
  #
  # So this is very insecure, need to figure out a solution.
  # Most likely the solution is to limit public endpoint access to
  # the IP address used to run this Terraform configuration and
  # use Functions or something to pass the data from IoT hub to database.
  #
  # Another option might be to use object storage instead of Postgresql.
  disable_public_endpoint = false
  volume_type = "bssd"
  volume_size_in_gb = 5
}
# Create the database
resource "scaleway_rdb_database" "main" {
  instance_id = scaleway_rdb_instance.database.id
  name = "database"
}
# Add the database user
resource "scaleway_rdb_user" "main" {
  instance_id = scaleway_rdb_instance.database.id
  name = random_string.database_user.result
  password = random_password.database_password.result
  is_admin = false
}
# Add privileges to the database for the user
resource "scaleway_rdb_privilege" "main" {
  instance_id = scaleway_rdb_instance.database.id
  user_name = scaleway_rdb_user.main.name
  database_name = scaleway_rdb_database.main.name
  permission = "all"
  depends_on = [ scaleway_rdb_instance.database, scaleway_rdb_database.main ]
}
# Create the database table for temperature measurements
resource "null_resource" "create_database" {
  provisioner "local-exec" {
    command = <<EOT
      psql -h "${scaleway_rdb_instance.database.endpoint_ip}" -p ${scaleway_rdb_instance.database.endpoint_port} \
        -U "${scaleway_rdb_user.main.name}" -d "${scaleway_rdb_database.main.name}" -c \
        "CREATE TABLE IF NOT EXISTS temperature (
          device_id VARCHAR(50) NOT NULL,
          temperature NUMERIC(5,2) NOT NULL,
          timestamp TIMESTAMP DEFAULT NOW()
        )"
    EOT

    environment = {
      PGPASSWORD = "${scaleway_rdb_user.main.password}"
    }
  }
  depends_on = [ scaleway_rdb_database.main, scaleway_rdb_user.main, scaleway_rdb_privilege.main ]
}
# Output the variables for example if local database access is required
output "database_user" {
  value = scaleway_rdb_user.main.name
  sensitive = true
}

output "database_password" {
  value = scaleway_rdb_user.main.password
  sensitive = true
}

output "database_ip" {
  value = scaleway_rdb_instance.database.endpoint_ip
  sensitive = true
}

output "database_port" {
  value = scaleway_rdb_instance.database.endpoint_port
  sensitive = true
}
