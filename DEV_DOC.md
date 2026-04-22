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

Host volumes (bind-mounted via local driver):
    DATA_PATH/db         → /var/lib/mysql  inside mariadb
    DATA_PATH/wordpress  → /var/www/html   inside wordpress and nginx
```

## Directory Structure

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
```

## Setup from Scratch

**1. Clone and enter the repo**
```bash
git clone <repo-url> Inception && cd Inception
```

**2. Create the environment file**
```bash
cp srcs/.env.example srcs/.env
```
Edit `srcs/.env` and fill in every variable. Key rules:
- `LOGIN` must be your 42 login
- `DATA_PATH` must be an absolute path (created automatically by `make`)
- `WP_ADMIN_USER` must NOT contain "admin" or "Admin" (eval requirement)
- `DOMAIN_NAME` must match what you add to `/etc/hosts`

**3. Register the domain locally**
```bash
echo "127.0.0.1 tmarcos.42.fr" | sudo tee -a /etc/hosts
```

**4. Build and start**
```bash
make
```

## Makefile Targets

| Target | What it does |
|--------|-------------|
| `make` / `make all` | Create data dirs, build images, start containers |
| `make down` | Stop containers (data untouched) |
| `make restart` | `down` + `all` |
| `make logs` | Follow live logs from all services |
| `make ps` | Show container status |
| `make clean` | Stop containers and remove Docker volumes |
| `make fclean` | Everything: containers, images, volumes, host data dirs |
| `make re` | `fclean` then `all` — full rebuild |
| `make eval` | Nuke all Docker state (run before evaluation) |

## Useful Commands

```bash
# Rebuild a single service without touching others
docker compose -f srcs/docker-compose.yml -p inception build mariadb
docker compose -f srcs/docker-compose.yml -p inception up -d mariadb

# Open a shell in a running container
docker exec -it mariadb bash
docker exec -it wordpress bash
docker exec -it nginx bash

# Log into MariaDB (credentials from srcs/.env)
docker exec -it mariadb mariadb -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"

# Run wp-cli commands
docker exec wordpress wp user list --allow-root
docker exec wordpress wp plugin list --allow-root

# Watch logs for one service
docker logs -f wordpress

# Confirm host path of a volume
docker volume inspect wp-db
docker volume inspect wp-files
```

## How Each Container Initialises

**mariadb** — On first start, `entrypoint.sh` checks for `/var/lib/mysql/.initialized`. If absent: runs `mysql_install_db`, starts a temporary mysqld, creates the database and user, sets the root password, writes the marker, then kills the temporary mysqld. Subsequent starts skip init and go straight to `exec mysqld`.

**wordpress** — On first start, `entrypoint.sh` waits for MariaDB to accept connections, then checks for `wp-config.php`. If absent: downloads WordPress core via wp-cli, generates `wp-config.php`, runs the installer, creates the admin and subscriber accounts. Subsequent starts skip setup and go straight to `exec php-fpm -F -R`.

**nginx** — On every start, generates a self-signed TLS certificate if `/etc/nginx/ssl/cert.pem` doesn't exist, then runs `exec nginx -g 'daemon off;'`.

## Why `exec` in Every Entrypoint

Every entrypoint ends with `exec <daemon>`. This replaces the shell process with the daemon — making it PID 1. Docker sends `SIGTERM` to PID 1 on stop. Without `exec`, the shell would be PID 1 and the daemon a child: `SIGTERM` would hit the shell, the shell exits, the daemon gets `SIGKILL` with no chance to flush data. With `exec`, the daemon handles `SIGTERM` gracefully.

## Adding a Bonus Service

1. Create `srcs/requirements/<service>/Dockerfile`
2. Add conf and entrypoint as needed
3. Add the service to `srcs/docker-compose.yml` on the `inception` network
4. Do not expose ports outside the `inception` network unless required
5. Build from `debian:bookworm` or `alpine:3.x` — no pre-built images
