FROM debian:bookworm

# Each RUN = one new filesystem layer (like a git commit on the image).
# We chain && to keep all steps in one layer so the apt cache doesn't bloat the image.
# rm -rf /var/lib/mysql: apt runs mysql_install_db during install which seeds this dir.
# If we leave it, Docker copies it into the volume and breaks our first-run detection.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        mariadb-server \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mysql \
    && mkdir -p /var/lib/mysql /run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /run/mysqld

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /tools/entrypoint.sh

RUN chmod +x /tools/entrypoint.sh

# EXPOSE is documentation only — it does not publish the port to the host.
# MariaDB is only reachable from inside the inception network.
EXPOSE 3306

ENTRYPOINT ["/tools/entrypoint.sh"]
