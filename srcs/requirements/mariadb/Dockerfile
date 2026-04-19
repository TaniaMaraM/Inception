FROM debian:bookworm

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        mariadb-server \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mysql \
    && mkdir -p /var/lib/mysql /run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /run/mysqld

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /tools/entrypoint.sh

RUN chmod +x /tools/entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["/tools/entrypoint.sh"]

# Each RUN = one new filesystem layer (like a git commit).
# That's why we chain && rm -rf /var/lib/apt/lists/* — it deletes the
# apt cache in the same layer so it doesn't bloat the image.
