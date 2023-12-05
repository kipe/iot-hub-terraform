# Database instance node type
variable "database_instance_type" {
  type    = string
  default = "DOCDB-PLAY2-PICO"
}
# Database instance name
variable "database_instance_name" {
  type    = string
  default = "database"
}
# Database volume in gigabytes?
variable "database_instance_volume_size" {
  type    = number
  default = 5
}
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
  length      = 22
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
  special     = true
}
# Create the database instance
resource "scaleway_documentdb_instance" "database" {
  name              = var.database_instance_name
  node_type         = var.database_instance_type
  engine            = "FerretDB-1"
  is_ha_cluster     = false
  volume_type       = "bssd"
  volume_size_in_gb = var.database_instance_volume_size
}
# Get the database load balancer information
# TODO: undocumented, file an issue
data "scaleway_documentdb_load_balancer_endpoint" "documentdb_lb" {
  instance_id = scaleway_documentdb_instance.database.id
}
# Create the database
resource "scaleway_documentdb_database" "main" {
  instance_id = scaleway_documentdb_instance.database.id
  name        = var.database_name
}
# Add the database user
resource "scaleway_documentdb_user" "main" {
  instance_id = scaleway_documentdb_instance.database.id
  name        = random_string.database_user.result
  password    = random_password.database_password.result
  is_admin    = false
}
# Add privileges to the database for the user
resource "scaleway_documentdb_privilege" "main" {
  instance_id   = scaleway_documentdb_instance.database.id
  user_name     = scaleway_documentdb_user.main.name
  database_name = scaleway_documentdb_database.main.name
  permission    = "all"
  depends_on    = [scaleway_documentdb_instance.database, scaleway_documentdb_database.main]
}
resource "scaleway_documentdb_privilege" "rdb" {
  instance_id   = scaleway_documentdb_instance.database.id
  user_name     = scaleway_documentdb_user.main.name
  database_name = "rdb"
  permission    = "all"
  depends_on    = [scaleway_documentdb_instance.database, scaleway_documentdb_database.main]
}
# Workaround for fetching the database certificate
# TODO: file an issue
data "http" "database_tls_cert" {
  url = "https://api.scaleway.com/document-db/v1beta1/regions/${scaleway_documentdb_instance.database.region}/instances/${replace("${scaleway_documentdb_instance.database.id}", "${scaleway_documentdb_instance.database.region}/", "")}/certificate"
  request_headers = {
    X-Auth-Token : var.scaleway_secret_key
  }
}
# Create environment file for functions, allowing easier local development
resource "local_sensitive_file" "functions-env" {
  filename        = "${path.root}/../.env"
  content         = <<EOT
DOCUMENTDB_DATABASE_IP="${data.scaleway_documentdb_load_balancer_endpoint.documentdb_lb.ip}"
DOCUMENTDB_DATABASE_NAME="${scaleway_documentdb_database.main.name}"
DOCUMENTDB_DATABASE_PASSWORD="${scaleway_documentdb_user.main.password}"
DOCUMENTDB_DATABASE_PORT="${data.scaleway_documentdb_load_balancer_endpoint.documentdb_lb.port}"
DOCUMENTDB_DATABASE_USER="${scaleway_documentdb_user.main.name}"
DOCUMENTDB_DATABASE_CERTIFICATE="${base64decode(jsondecode(data.http.database_tls_cert.response_body).content)}"
  EOT
  file_permission = 0600
}
