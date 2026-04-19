# Developer Documentation — Inception

## Architecture

```
Host (VM)
└── Docker bridge network: inception
    ├── nginx          (port 443 published to host)
    │   └── forwards .php requests to wordpress:9000 via FastCGI
    ├── wordpress      (php-fpm on port 9000, internal only)
    │   └── connects to mariadb:3306
    └── mariadb        (port 3306, internal only)

Host volumes (bind-mounted):
    DATA_PATH/db         → mounted at /var/lib/mysql inside mariadb
    DATA_PATH/wordpress  → mounted at /var/www/html inside wordpress and nginx
```

## Directory structure

```
Inception/
├── Makefile
├── srcs/
│   ├── .env                  (gitignored — copy from .env.example)
│   ├── .env.example
│   ├── docker-compose.yml
│   └── requirements/
│       ├── mariadb/
│       │   ├── Dockerfile
│       │   ├── conf/50-server.cnf
│       │   └── tools/entrypoint.sh
│       ├── wordpress/
│       │   ├── Dockerfile
│       │   ├── conf/www.conf
│       │   └── tools/entrypoint.sh
│       └── nginx/
│           ├── Dockerfile
│           ├── conf/default.conf
│           └── tools/entrypoint.sh
└── secrets/               (gitignored — optional plaintext credential files)
```

## Setup from scratch

**1. Clone and enter the repo**
```bash
git clone <repo-url> Inception
cd Inception
```

**2. Create the environment file**
```bash
cp srcs/.env.example srcs/.env
```
Edit `srcs/.env` and fill in every variable. Key rules:
- `LOGIN` must be your 42 login
- `DATA_PATH` must be an absolute path that exists (or will be created by `make`)
- `WP_ADMIN_USER` must NOT contain "admin" or "Admin"
- `DOMAIN_NAME` must match what you put in `/etc/hosts`

**3. Register the domain locally**
```bash
echo "127.0.0.1 login.42.fr" | sudo tee -a /etc/hosts
```
Replace `login.42.fr` with your actual `DOMAIN_NAME`.

**4. Build and start**
```bash
make
```

## Makefile targets

| Target | What it does |
|--------|-------------|
| `make` / `make all` | Create data directories, build images, start containers |
| `make down` | Stop and remove containers (data untouched) |
| `make clean` | Stop containers, remove volumes (host data survives) |
| `make fclean` | Everything: containers, images, Docker volumes, host data dirs |
| `make re` | `fclean` then `all` — full rebuild from scratch |

## Useful commands

```bash
# Rebuild a single service without touching others
docker compose -f srcs/docker-compose.yml build mariadb
docker compose -f srcs/docker-compose.yml up -d mariadb

# Open a shell in a running container
docker exec -it mariadb bash
docker exec -it wordpress bash
docker exec -it nginx bash

# Log into MariaDB directly
docker exec -it mariadb mariadb -u wpuser -pwpuserpass123 wordpress

# Run wp-cli commands
docker exec wordpress wp user list --allow-root
docker exec wordpress wp plugin list --allow-root

# Watch logs in real time
docker logs -f wordpress

# Inspect a volume to confirm host path
docker volume inspect inception_wp-db
```

## How each container initializes

**mariadb** — On first start, `entrypoint.sh` checks for a marker file at `/var/lib/mysql/.initialized`. If absent: runs `mysql_install_db`, starts a temporary mysqld, creates the database and user, sets the root password, writes the marker, then kills the temporary mysqld. On all subsequent starts, skips initialization and goes straight to `exec mysqld`.

**wordpress** — On first start, `entrypoint.sh` waits for MariaDB to accept connections, then checks for `wp-config.php`. If absent: downloads WordPress core via wp-cli, generates `wp-config.php`, runs the WordPress installer, creates the admin and subscriber accounts. On all subsequent starts, skips setup and goes straight to `exec php-fpm8.2 -F -R`.

**nginx** — On every start, generates a self-signed TLS certificate if `/etc/nginx/ssl/cert.pem` doesn't exist, then runs `exec nginx -g 'daemon off;'`.

## Why `exec` in every entrypoint

Every entrypoint ends with `exec <daemon>`. The `exec` replaces the shell process with the daemon — the daemon becomes PID 1. This matters because Docker sends `SIGTERM` to PID 1 when stopping a container. If the shell were PID 1 and the daemon were a child, `SIGTERM` would go to the shell, the shell would exit, the daemon would be killed with `SIGKILL` without a chance to flush data. With `exec`, the daemon handles `SIGTERM` gracefully.

## Adding a bonus service

1. Create `srcs/requirements/<service>/Dockerfile`
2. Add conf and entrypoint as needed
3. Add the service to `srcs/docker-compose.yml` on the `inception` network
4. Do not expose ports outside the `inception` network unless required
5. Do not use a pre-built image — write the Dockerfile from `debian:bookworm`
