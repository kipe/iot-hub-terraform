# Bundle requirements to package -directory
data "pypi_requirements_file" "requirements" {
  requirements_file = "${path.root}/../functions/measurement/requirements.txt"
  output_dir        = "${path.root}/../functions/measurement/package"
}
# Zip up the measurement function, including the package created in the previous step
data "archive_file" "measurement_archive" {
  type                        = "zip"
  source_dir                  = "${path.root}/../functions/measurement"
  exclude_symlink_directories = true
  excludes = [
    "requirements.txt",
    "requirements-dev.txt",
  ]
  output_file_mode = "0666"
  output_path      = "${path.root}/../functions/measurement.zip"

  depends_on = [data.pypi_requirements_file.requirements]
}
# Create a namespace to hold the functions
resource "scaleway_function_namespace" "functions" {
  name = "functions"
}
# Create a function to handle incoming and outgoing measurements
resource "scaleway_function" "measurement" {
  namespace_id = scaleway_function_namespace.functions.id
  name         = "measurement"
  runtime      = "python311"
  handler      = "measurement.measurement"
  privacy      = "public"
  zip_file     = data.archive_file.measurement_archive.output_path
  zip_hash     = data.archive_file.measurement_archive.output_sha
  http_option  = "redirected"
  deploy       = true

  min_scale    = 0
  max_scale    = 1
  memory_limit = 128
  timeout      = 30

  secret_environment_variables = {
    "DOCUMENTDB_DATABASE_IP"          = data.scaleway_documentdb_load_balancer_endpoint.documentdb_lb.ip
    "DOCUMENTDB_DATABASE_NAME"        = scaleway_documentdb_database.main.name
    "DOCUMENTDB_DATABASE_PASSWORD"    = scaleway_documentdb_user.main.password
    "DOCUMENTDB_DATABASE_PORT"        = data.scaleway_documentdb_load_balancer_endpoint.documentdb_lb.port
    "DOCUMENTDB_DATABASE_USER"        = "${scaleway_documentdb_user.main.name}"
    "DOCUMENTDB_DATABASE_CERTIFICATE" = base64decode(jsondecode(data.http.database_tls_cert.response_body).content)
  }
}
