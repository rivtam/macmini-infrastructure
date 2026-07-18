ui = true

# Storage backend - using file storage for simplicity
# For production, consider using Consul, etcd, or cloud storage
storage "file" {
  path = "/vault/data"
}

# Listener for API and UI
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1  # Set to 0 and configure TLS for production
}

# API address
api_addr = "http://127.0.0.1:8200"

# Cluster address (for HA setups)
cluster_addr = "http://127.0.0.1:8201"

# Enable Prometheus metrics
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}

# Disable mlock for containerized environments
disable_mlock = true

# Default lease duration
default_lease_ttl = "168h"  # 7 days
max_lease_ttl = "720h"      # 30 days
