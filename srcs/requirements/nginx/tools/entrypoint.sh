#!/bin/bash
set -e

if [ ! -f /etc/nginx/ssl/cert.pem ]; then
    openssl req -x509 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/key.pem \
        -out  /etc/nginx/ssl/cert.pem \
        -days 365 \
        -nodes \
        -subj "/C=FR/ST=IDF/L=Paris/O=42/CN=${DOMAIN_NAME}"
fi

exec nginx -g 'daemon off;'
