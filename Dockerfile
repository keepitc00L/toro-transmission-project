# ============================================
# Toro Transmission — Production Container
# Static site served by Nginx on Alpine Linux
# ============================================

FROM nginx:1.27-alpine

LABEL maintainer="Toro Transmission DevOps"
LABEL description="Toro Transmission static website"
LABEL version="2.0"

# Remove default nginx content
RUN rm -rf /usr/share/nginx/html/*

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy application files
COPY index.html /usr/share/nginx/html/
COPY style.css /usr/share/nginx/html/
COPY script.js /usr/share/nginx/html/
COPY logo.png /usr/share/nginx/html/
COPY gear_motor_1.png /usr/share/nginx/html/
COPY gear_motor_2.png /usr/share/nginx/html/
COPY gear_motor_3.png /usr/share/nginx/html/
COPY gear_motor_4.png /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost/ || exit 1

# Start nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
