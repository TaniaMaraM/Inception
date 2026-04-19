#!/bin/bash
set -e

MARKER=/var/lib/mysql/.initialized

if [ ! -f "$MARKER" ]; then

    echo "[mariadb] First run — initializing data directory..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql --skip-test-db

    # Start a temporary instance with no network access.
    # We connect via the unix socket only during initialization.
    mysqld --user=mysql --skip-networking &
    TEMP_PID=$!

    until mysqladmin ping --silent 2>/dev/null; do
        sleep 1
    done

    # Write SQL to a file — avoids heredoc quoting/tab-stripping edge cases.
    # All values come from environment variables; no credentials in source code.
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

    echo "[mariadb] Initialization complete."
fi

# execve() replaces this shell with mysqld, making it PID 1.
exec mysqld --user=mysql
