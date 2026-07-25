# Infrastructure Nginx with custom configs
FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY sites /etc/nginx/sites-enabled

# Create log directory
RUN mkdir -p /var/log/nginx

# Expose ports
EXPOSE 80 443

# Healthcheck is defined in docker-compose.yml

CMD ["nginx", "-g", "daemon off;"]
