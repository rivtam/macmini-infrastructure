# Policy for infrastructure services to read secrets

# Database secrets
path "secret/data/databases/*" {
  capabilities = ["read", "list"]
}

# Application secrets
path "secret/data/applications/*" {
  capabilities = ["read", "list"]
}

# Monitoring secrets
path "secret/data/monitoring/*" {
  capabilities = ["read", "list"]
}

# Allow listing secret paths
path "secret/metadata/*" {
  capabilities = ["list"]
}
