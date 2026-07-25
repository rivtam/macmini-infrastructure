# Custom Prometheus with pre-configured alerts and rules
FROM prom/prometheus:latest

# Copy custom configuration
COPY prometheus/prometheus.yml /etc/prometheus/prometheus.yml
COPY prometheus/alerts /etc/prometheus/alerts

# Expose Prometheus port
EXPOSE 9090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:9090/-/healthy || exit 1

# Use default entrypoint with custom config
CMD ["--config.file=/etc/prometheus/prometheus.yml", \
     "--storage.tsdb.path=/prometheus", \
     "--web.console.libraries=/etc/prometheus/console_libraries", \
     "--web.console.templates=/etc/prometheus/consoles", \
     "--storage.tsdb.retention.time=30d", \
     "--web.enable-lifecycle"]
