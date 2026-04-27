#!/bin/bash
set -e

WP_PATH=/var/www/html

# Wait until MariaDB is ready to accept connections.
# depends_on only waits for the container to start, not the service inside it.
until mariadb -h "${MYSQL_HOSTNAME}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" -e ";" 2>/dev/null; do
    echo "[wordpress] Waiting for MariaDB..."
    sleep 2
done

# If wp-config.php exists, WordPress was already installed — skip setup.
# Files live on the volume and survive container restarts.
if [ ! -f "${WP_PATH}/wp-config.php" ]; then

    # Download the WordPress core files into WP_PATH.
    wp core download --path="${WP_PATH}" --allow-root

    # Create wp-config.php with DB credentials from the .env file.
    wp config create \
        --path="${WP_PATH}" \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="${MYSQL_HOSTNAME}" \
        --allow-root

    # Install WordPress (creates tables, sets admin credentials).
    wp core install \
        --path="${WP_PATH}" \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --path="${WP_PATH}" \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=subscriber \
        --allow-root

fi

# Replace this shell with php-fpm as PID 1.
# -F = run in foreground, -R = allow running as root.
exec php-fpm8.2 -F -R
