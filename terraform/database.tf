# Database instance node type
variable "database_instance_type" {
  type    = string
  default = "DB-DEV-S"
}
# Database instance name
variable "database_instance_name" {
  type    = string
  default = "database"
}
# Disable database backups?
variable "database_instance_disable_backup" {
  type    = bool
  default = true
}
# Database volume in gigabytes?
variable "database_instance_volume_size" {
  type    = number
  default = 5
}
# Database name
variable "database_name" {
  type    = string
  default = "database"
}
# Create a random string to use as the database user
resource "random_string" "database_user" {
  length  = 12
  numeric = false
  special = false
}
# Create random password for database
resource "random_password" "database_password" {
  length  = 16
  special = true
}
# Create the database instance
resource "scaleway_rdb_instance" "database" {
  name           = var.database_instance_name
  node_type      = var.database_instance_type
  engine         = "PostgreSQL-15"
  is_ha_cluster  = false
  disable_backup = var.database_instance_disable_backup
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
  volume_type             = "bssd"
  volume_size_in_gb       = var.database_instance_volume_size
}
# Setup ACL to allow connections from Scaleway and current IP
resource "scaleway_rdb_acl" "database" {
  instance_id = scaleway_rdb_instance.database.id
  dynamic "acl_rules" {
    for_each = var.scaleway_peering
    content {
      ip          = acl_rules.value
      description = "Scaleway peering"
    }
  }
  acl_rules {
    ip          = "${chomp(data.http.current_ip.response_body)}/32"
    description = "current ip"
  }
}

# Create the database
resource "scaleway_rdb_database" "main" {
  instance_id = scaleway_rdb_instance.database.id
  name        = var.database_name
}
# Add the database user
resource "scaleway_rdb_user" "main" {
  instance_id = scaleway_rdb_instance.database.id
  name        = random_string.database_user.result
  password    = random_password.database_password.result
  is_admin    = false
}
# Add privileges to the database for the user
resource "scaleway_rdb_privilege" "main" {
  instance_id   = scaleway_rdb_instance.database.id
  user_name     = scaleway_rdb_user.main.name
  database_name = scaleway_rdb_database.main.name
  permission    = "all"
  depends_on    = [scaleway_rdb_instance.database, scaleway_rdb_database.main]
}
# Output the variables for example if local database access is required
output "database_user" {
  value     = scaleway_rdb_user.main.name
  sensitive = true
}
output "database_password" {
  value     = scaleway_rdb_user.main.password
  sensitive = true
}
output "database_name" {
  value     = scaleway_rdb_database.main.name
  sensitive = true
}
output "database_ip" {
  value     = scaleway_rdb_instance.database.endpoint_ip
  sensitive = true
}
output "database_port" {
  value     = scaleway_rdb_instance.database.endpoint_port
  sensitive = true
}
