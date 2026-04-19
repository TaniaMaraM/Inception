# User Documentation — Inception

## What this project runs

Three services accessible through a single HTTPS endpoint:

- **WordPress site** — `https://tmarcos.42.fr`
- **WordPress admin panel** — `https://tmarcos.42.fr/wp-admin`
- **MariaDB** — accessible only from inside the Docker network (not from the browser)

The self-signed TLS certificate will trigger a browser warning. Click "Advanced" and proceed — this is expected for a local development setup.

## Prerequisites

- Docker and Docker Compose installed
- The file `srcs/.env` exists and is filled in (copy from `srcs/.env.example`)
- `/etc/hosts` contains: `127.0.0.1 tmarcos.42.fr`

## Starting and stopping

```bash
# Start the full stack (builds images on first run, may take a few minutes)
make

# Stop containers without losing data
make down

# Start again after make down (images already built, fast)
make all
```

## Accessing the site

Open `https://tmarcos.42.fr` in a browser. Accept the certificate warning.

**Admin panel**: `https://tmarcos.42.fr/wp-admin`
- Username and password are in `srcs/.env` under `WP_ADMIN_USER` and `WP_ADMIN_PASSWORD`

## Where credentials are stored

All credentials are in `srcs/.env` (this file is gitignored and never committed).

| Variable | Purpose |
|----------|---------|
| `MYSQL_USER` / `MYSQL_PASSWORD` | WordPress database user |
| `MYSQL_ROOT_PASSWORD` | MariaDB root password |
| `WP_ADMIN_USER` / `WP_ADMIN_PASSWORD` | WordPress admin login |
| `WP_USER` / `WP_USER_PASSWORD` | WordPress subscriber account |

## Checking that services are running

```bash
# List running containers
docker ps

# Follow logs for a specific service
docker logs -f wordpress
docker logs -f mariadb
docker logs -f nginx

# Check all three are up
docker compose -f srcs/docker-compose.yml ps
```

All three containers should show status `Up`. If one is restarting repeatedly, check its logs.

## Data persistence

Data is stored on the host at the path set by `DATA_PATH` in `srcs/.env`. It survives container restarts and rebuilds. It is only deleted by `make fclean`.

```bash
# See where volumes are stored on the host
docker volume inspect inception_wp-db
docker volume inspect inception_wp-files
```

## Resetting everything

```bash
# Full wipe: removes containers, images, volumes, and host data directories
make fclean

# Rebuild from scratch
make
```
