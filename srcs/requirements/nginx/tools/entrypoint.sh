#!/bin/bash
set -e

# Generate a self-signed TLS certificate on first run.
# CN uses DOMAIN_NAME from the .env file so it matches the site URL.
# The certificate doesn't need to be trusted — the evaluator clicks through
# the browser warning. What matters is TLSv1.2/1.3 is in use.
if [ ! -f /etc/nginx/ssl/cert.pem ]; then
    openssl req -x509 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/key.pem \
        -out  /etc/nginx/ssl/cert.pem \
        -days 365 \
        -nodes \
        -subj "/C=FR/ST=IDF/L=Paris/O=42/CN=${DOMAIN_NAME}"
fi

# daemon off: prevents nginx from forking to the background.
# Without it, nginx would daemonize, the shell would exit, and
# the container would stop immediately (PID 1 gone).
exec nginx -g 'daemon off;'
