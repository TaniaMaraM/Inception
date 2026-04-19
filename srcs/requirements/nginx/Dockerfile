FROM debian:bookworm

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        nginx \
        openssl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /etc/nginx/ssl \
    && rm -f /etc/nginx/sites-enabled/default

COPY conf/default.conf /etc/nginx/conf.d/default.conf
COPY tools/entrypoint.sh /tools/entrypoint.sh

RUN chmod +x /tools/entrypoint.sh

EXPOSE 443

ENTRYPOINT ["/tools/entrypoint.sh"]
