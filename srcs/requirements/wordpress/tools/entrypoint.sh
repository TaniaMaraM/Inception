#!/bin/bash
set -e

WP_PATH=/var/www/html

# Wait for MariaDB to accept connections before doing anything.
# depends_on in docker-compose only waits for the CONTAINER to start,
# not for the SERVICE inside it to be ready. We have to poll ourselves.
until mariadb -h mariadb -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" -e ";" 2>/dev/null; do
    echo "[wordpress] Waiting for MariaDB..."
    sleep 2
done
echo "[wordpress] MariaDB is ready."

# Check if WordPress was already installed (volume has wp-config.php from a previous run).
if [ ! -f "${WP_PATH}/wp-config.php" ]; then

    echo "[wordpress] First run — downloading and configuring WordPress..."

    # Download WordPress core files into the volume.
    wp core download --path="${WP_PATH}" --allow-root

    # Create wp-config.php with the database connection settings.
    # dbhost is the service name 'mariadb' — Docker's internal DNS resolves it.
    wp config create \
        --path="${WP_PATH}" \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost=mariadb \
        --allow-root

    # Install WordPress and create the admin account.
    # Admin username must NOT contain 'admin' or 'Admin' — evaluator checks this.
    wp core install \
        --path="${WP_PATH}" \
        --url="https://${DOMAIN_NAME}" \
        --title="Inception" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    # Create the second (regular subscriber) user.
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --path="${WP_PATH}" \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=subscriber \
        --allow-root

    echo "[wordpress] WordPress installed successfully."
fi

# Replace this shell with php-fpm as PID 1.
# -F  = foreground (no daemonize)
# -R  = allow running as root (master process only; workers run as www-data)
exec php-fpm8.2 -F -R
