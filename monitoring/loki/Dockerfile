# Custom Loki with infrastructure log retention config
FROM grafana/loki:latest

# Copy custom configuration
COPY loki/loki-config.yml /etc/loki/loki-config.yml

# Expose Loki port
EXPOSE 3100

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3100/ready || exit 1

CMD ["-config.file=/etc/loki/loki-config.yml"]
