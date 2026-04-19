#!/bin/bash
set -e

MARKER=/var/lib/mysql/.initialized

if [ ! -f "$MARKER" ]; then

    mysql_install_db --user=mysql --datadir=/var/lib/mysql --skip-test-db

    mysqld --user=mysql --skip-networking &
    TEMP_PID=$!

    until mysqladmin ping --silent 2>/dev/null; do
        sleep 1
    done

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

exec mysqld --user=mysql
