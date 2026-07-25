# Custom Grafana with pre-provisioned dashboards and datasources
FROM grafana/grafana:latest

# Copy provisioning configs
COPY dashboards /etc/grafana/provisioning/dashboards
COPY datasources /etc/grafana/provisioning/datasources

# Copy dashboard JSON files
COPY dashboards/json /etc/grafana/provisioning/dashboards/json

# Set permissions
USER root
RUN chown -R grafana:grafana /etc/grafana/provisioning
USER grafana

# Expose Grafana port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1
