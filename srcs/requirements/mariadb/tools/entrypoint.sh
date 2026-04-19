#!/bin/bash
set -e

# Marker file: if it exists, the DB was already initialized on a previous run.
# We can't check for /var/lib/mysql/mysql because with a bind-mount volume
# Docker doesn't seed the host directory from the image — it stays empty.
MARKER=/var/lib/mysql/.initialized

if [ ! -f "$MARKER" ]; then

    # Bootstrap the data directory (creates system tables).
    mysql_install_db --user=mysql --datadir=/var/lib/mysql --skip-test-db

    # Start a temporary instance with no network — only the unix socket is open.
    # We don't want other containers connecting while we're initializing.
    mysqld --user=mysql --skip-networking &
    TEMP_PID=$!

    until mysqladmin ping --silent 2>/dev/null; do
        sleep 1
    done

    # Write SQL to a temp file — avoids heredoc quoting edge cases.
    # All credentials come from environment variables, never hardcoded.
    cat > /tmp/init.sql << EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

    mysql --user=root < /tmp/init.sql
    rm /tmp/init.sql
    touch "$MARKER"

    kill $TEMP_PID
    wait $TEMP_PID 2>/dev/null || true

fi

# exec replaces this shell with mysqld — mysqld becomes PID 1.
# Docker sends SIGTERM to PID 1 on docker stop, so mysqld shuts down cleanly.
exec mysqld --user=mysql
