# Custom Alertmanager with alert routing and templates
FROM prom/alertmanager:latest

# Copy custom configuration
COPY alertmanager/alertmanager.yml /etc/alertmanager/alertmanager.yml
COPY alertmanager/templates /etc/alertmanager/templates

# Expose Alertmanager port
EXPOSE 9093

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:9093/-/healthy || exit 1

CMD ["--config.file=/etc/alertmanager/alertmanager.yml", \
     "--storage.path=/alertmanager", \
     "--web.external-url=http://localhost:9093"]
