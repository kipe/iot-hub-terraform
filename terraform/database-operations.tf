# Create the database table for temperature measurements
resource "null_resource" "create_tables" {
  provisioner "local-exec" {
    when = create
    environment = {
      PGPASSWORD = "${scaleway_rdb_user.main.password}"
    }
    command = <<EOT
      psql -h "${scaleway_rdb_instance.database.endpoint_ip}" -p ${scaleway_rdb_instance.database.endpoint_port} \
        -U "${scaleway_rdb_user.main.name}" -d "${scaleway_rdb_database.main.name}" -c \
        "CREATE TABLE IF NOT EXISTS temperature (
          device_id VARCHAR(50) NOT NULL,
          temperature NUMERIC(5,2) NOT NULL,
          timestamp TIMESTAMP DEFAULT NOW()
        );"
    EOT
  }

  depends_on = [ scaleway_rdb_database.main, scaleway_rdb_user.main, scaleway_rdb_privilege.main ]
  triggers = {
    database_name = scaleway_rdb_database.main.name
  }
}
