#!/bin/bash
yum update -y
yum install -y nginx
systemctl start nginx
systemctl enable nginx

# Write nginx config with proxy to app server
# Note: no quotes around NGINXEOF so ${app_server_ip} gets substituted
cat > /etc/nginx/nginx.conf << NGINXEOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    keepalive_timeout 65;

    server {
        listen 80;
        server_name _;
        root /usr/share/nginx/html;

        location /cart {
            proxy_pass http://${app_server_ip}:8080/cart;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }

        location / {
            try_files \$uri \$uri/ =404;
        }

        error_page 404 /404.html;
        error_page 500 502 503 504 /50x.html;
    }
}
NGINXEOF

systemctl restart nginx
