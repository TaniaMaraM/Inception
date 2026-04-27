#!/bin/bash
set -e

# If the certificate does not exist yet, generate a self-signed TLS certificate.
if [ ! -f /etc/nginx/ssl/cert.pem ]; then
    openssl req -x509 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/key.pem \
        -out  /etc/nginx/ssl/cert.pem \
        -days 365 \
        -nodes \
        -subj "/C=FR/ST=IDF/L=Paris/O=42/CN=${DOMAIN_NAME}"
fi

# 'daemon off' keeps nginx in the foreground — Docker can shut it down cleanly.
exec nginx -g 'daemon off;'





















# If the certificate does not exist yet, generate a self-signed TLS certificate.
# On container restarts the file already exists, so this block is skipped.
#   -x509        : standard certificate format
#   -newkey rsa  : generate a new RSA 2048-bit private key
#   -nodes       : no password on the key (nginx needs to read it automatically)
#   -days 365    : certificate valid for 1 year
#   -subj        : fill in certificate fields without an interactive prompt;
#                  CN is set to DOMAIN_NAME so it matches the site URL
