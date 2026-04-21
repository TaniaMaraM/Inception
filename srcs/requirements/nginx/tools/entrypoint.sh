#!/bin/bash
set -e

# Generate a self-signed TLS certificate on first run.
# CN uses DOMAIN_NAME from the .env file so it matches the site URL.
# the browser warning. What matters is TLSv1.2/1.3 is in use.
if [ ! -f /etc/nginx/ssl/cert.pem ]; then
    openssl req -x509 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/key.pem \
        -out  /etc/nginx/ssl/cert.pem \
        -days 365 \
        -nodes \
        -subj "/C=FR/ST=IDF/L=Paris/O=42/CN=${DOMAIN_NAME}"
fi

# exec replaces this shell with nginx as PID 1.
# 'daemon off' keeps nginx in the foreground — without it nginx would fork
# to the background, PID 1 (the shell) would exit, and the container would stop.
exec nginx -g 'daemon off;'
