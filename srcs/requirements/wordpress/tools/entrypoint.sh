#!/bin/bash
set -e

WP_PATH=/var/www/html

# depends_on in docker-compose only waits for the container to start, not for
# the service inside it to be ready. We poll until MariaDB accepts connections.
until mariadb -h "${MYSQL_HOSTNAME}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" -e ";" 2>/dev/null; do
    echo "[wordpress] Waiting for MariaDB..."
    sleep 2
done

# If wp-config.php exists, WordPress was already installed on a previous run.
# The files live on the volume, so they survive container restarts.
if [ ! -f "${WP_PATH}/wp-config.php" ]; then

    wp core download --path="${WP_PATH}" --allow-root

    # dbhost is the service name 'mariadb' — Docker's internal DNS resolves it.
    wp config create \
        --path="${WP_PATH}" \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="${MYSQL_HOSTNAME}" \
        --allow-root

    # Admin username must NOT contain 'admin' or 'Admin' — evaluation requirement.
    wp core install \
        --path="${WP_PATH}" \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    # Second user with subscriber role — required by the project spec.
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --path="${WP_PATH}" \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=subscriber \
        --allow-root

fi

# exec replaces this shell with php-fpm as PID 1.
# -F = foreground (no daemonize), -R = allow running as root
exec php-fpm8.2 -F -R
