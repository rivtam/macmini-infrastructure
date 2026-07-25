# Custom Promtail with infrastructure log collection config
FROM grafana/promtail:latest

# Copy custom configuration
COPY promtail/promtail-config.yml /etc/promtail/promtail-config.yml

# Expose Promtail port
EXPOSE 9080

CMD ["-config.file=/etc/promtail/promtail-config.yml"]
