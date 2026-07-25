# Custom Grafana with pre-provisioned dashboards and datasources
FROM grafana/grafana:latest

# Copy provisioning configs (grafana user already owns /etc/grafana)
COPY --chown=grafana:grafana grafana/dashboards /etc/grafana/provisioning/dashboards
COPY --chown=grafana:grafana grafana/datasources /etc/grafana/provisioning/datasources

# Expose Grafana port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1
