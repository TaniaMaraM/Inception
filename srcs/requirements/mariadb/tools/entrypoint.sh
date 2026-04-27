#!/bin/bash
# Stop the script immediately if any command fails.
set -e

# If this file exists, the DB was already set up — skip initialisation.
MARKER=/var/lib/mysql/.initialized

if [ ! -f "$MARKER" ]; then

    # Create the raw data directory so MySQL can start for the first time.
    mysql_install_db --user=mysql --datadir=/var/lib/mysql --skip-test-db

    # Start a temporary MySQL with no network — only localhost, no password yet.
    mysqld --user=mysql --skip-networking &
    TEMP_PID=$!

    # Wait until the server is ready to accept connections.
    until mysqladmin ping --silent 2>/dev/null; do
        sleep 1
    done

    # Write the SQL setup script using values from the .env file.
    cat > /tmp/init.sql << EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

    # Run the SQL script (creates DB, user, passwords), then delete it (contains passwords).
    # Create the marker file so this block is skipped on the next container start.
    mysql --user=root < /tmp/init.sql
    rm /tmp/init.sql
    touch "$MARKER"

    # Shut down the temporary server before handing off to the real one.
    kill $TEMP_PID
    wait $TEMP_PID 2>/dev/null || true

fi

# Replace this shell with mysqld as PID 1 — Docker can shut it down cleanly.
exec mysqld --user=mysql
