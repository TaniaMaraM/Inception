FROM debian:bookworm

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        php8.2-fpm \
        php8.2-mysql \
        php8.2-curl \
        php8.2-gd \
        php8.2-mbstring \
        php8.2-xml \
        php8.2-zip \
        curl \
        mariadb-client \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/php /var/www/html \
    && curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/entrypoint.sh /tools/entrypoint.sh

RUN chmod +x /tools/entrypoint.sh

EXPOSE 9000

ENTRYPOINT ["/tools/entrypoint.sh"]
