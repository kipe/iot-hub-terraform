# Create the database tables for measurements
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
        CREATE TABLE IF NOT EXISTS device (
          id BIGSERIAL PRIMARY KEY,
          device VARCHAR(50) NOT NULL,
          name VARCHAR(255),
          description TEXT,
          labels JSONB,
          last_seen TIMESTAMPTZ NOT NULL,
          last_message JSONB,
          UNIQUE(device)
        );
        CREATE TABLE IF NOT EXISTS temperature (
          time TIMESTAMPTZ NOT NULL,
          device_id BIGINT NOT NULL REFERENCES device (id),
          temperature NUMERIC(5,2) NOT NULL,
          labels JSONB
        );
        CREATE TABLE IF NOT EXISTS cpu_usage (
          time TIMESTAMPTZ NOT NULL,
          device_id BIGINT NOT NULL REFERENCES device (id),
          cpu_usage NUMERIC(5,2) NOT NULL,
          labels JSONB
        );
        SELECT create_hypertable('cpu_usage', 'time');"
    EOT
  }

  depends_on = [scaleway_rdb_database.main, scaleway_rdb_user.main, scaleway_rdb_privilege.main]
  triggers = {
    database_name = scaleway_rdb_database.main.name
  }
}
