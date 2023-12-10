# Create the database table for temperature measurements
resource "null_resource" "create_tables" {
  provisioner "local-exec" {
    when = create
    environment = {
      PGPASSWORD = "${scaleway_rdb_user.main.password}"
    }
    command = <<-EOT
      psql -h "${scaleway_rdb_instance.database.endpoint_ip}" -p ${scaleway_rdb_instance.database.endpoint_port} \
        -U "${scaleway_rdb_user.main.name}" -d "${scaleway_rdb_database.main.name}" -c "
        CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
        CREATE TABLE IF NOT EXISTS devices (
          id BIGSERIAL PRIMARY KEY,
          device VARCHAR(50) NOT NULL,
          last_seen TIMESTAMPTZ NOT NULL,
          temperature NUMERIC(5, 2) NOT NULL,
          UNIQUE(device)
        );
        CREATE TABLE IF NOT EXISTS temperature (
          time TIMESTAMPTZ NOT NULL,
          device_id BIGINT NOT NULL REFERENCES devices (id),
          temperature NUMERIC(5,2) NOT NULL
        );
        SELECT create_hypertable('temperature', 'time');"
    EOT
  }

  depends_on = [scaleway_rdb_database.main, scaleway_rdb_user.main, scaleway_rdb_privilege.main]
  triggers = {
    database_name = scaleway_rdb_database.main.name
  }
}
