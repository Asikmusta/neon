FROM nginx:latest

# Create necessary directories with correct permissions
RUN mkdir -p /var/cache/nginx/client_temp && \
    chmod -R 755 /var/cache/nginx && \
    chown -R nginx:nginx /var/cache/nginx

# Copy your content
COPY . /usr/share/nginx/html

# Set the user (nginx user already exists in the base image)
USER nginx
