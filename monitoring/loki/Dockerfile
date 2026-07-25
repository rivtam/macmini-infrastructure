# Custom Loki with infrastructure log retention config
FROM grafana/loki:latest

# Copy custom configuration
COPY loki/loki-config.yml /etc/loki/loki-config.yml

# Expose Loki port
EXPOSE 3100

# Note: Healthcheck removed - Loki base image doesn't have wget/curl
# Health monitoring can be done via Prometheus scraping /metrics

CMD ["-config.file=/etc/loki/loki-config.yml"]
