# Infrastructure Nginx with custom configs
FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY sites /etc/nginx/sites-enabled

# Create log directory
RUN mkdir -p /var/log/nginx

# Add healthcheck endpoint
RUN echo 'OK' > /usr/share/nginx/html/healthz

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
