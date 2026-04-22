# User Documentation — Inception

## What This Project Runs

Three services, one HTTPS endpoint:

| Service | Role | Accessible From |
|---------|------|-----------------|
| **NGINX** | Reverse proxy, TLS termination | Browser via port 443 |
| **WordPress** | CMS, page rendering (php-fpm) | Via NGINX only |
| **MariaDB** | Database | Inside Docker network only |

> The self-signed TLS certificate will trigger a browser warning — this is expected.
> Click "Advanced" → "Proceed" to continue.

---

## Prerequisites

- Docker and Docker Compose installed
- `srcs/.env` exists and is filled in (copy from `srcs/.env.example`)
- `/etc/hosts` contains the line:
  ```
  127.0.0.1 tmarcos.42.fr
  ```

---

## Makefile Commands

| Command | What it does |
|---------|--------------|
| `make` | Build images and start all services |
| `make down` | Stop containers (data is preserved) |
| `make restart` | Stop then start again |
| `make logs` | Follow live logs from all services |
| `make ps` | Show running containers and their status |
| `make clean` | Stop containers and remove volumes |
| `make fclean` | Full wipe: containers, images, volumes, host data |
| `make re` | `fclean` + full rebuild from scratch |
| `make eval` | Nuke all Docker state (run before evaluation) |

---

## Accessing the Site

Once running, open your browser:

- **Website** — `https://tmarcos.42.fr`
- **Admin panel** — `https://tmarcos.42.fr/wp-admin`

---

## Credentials

All credentials live in `srcs/.env` (gitignored, never committed).

| Variable | Purpose |
|----------|---------|
| `MYSQL_USER` / `MYSQL_PASSWORD` | WordPress DB user |
| `MYSQL_ROOT_PASSWORD` | MariaDB root |
| `WP_ADMIN_USER` / `WP_ADMIN_PASSWORD` | WordPress administrator |
| `WP_USER` / `WP_USER_PASSWORD` | WordPress subscriber account |

---

## Checking Services

```bash
make ps                        # show all containers and their state
make logs                      # follow live output from all services
docker logs -f nginx           # logs for a single service
docker logs -f wordpress
docker logs -f mariadb
```

All three containers should show status `Up`. If one is restarting, its logs will say why.

---

## Data Persistence

Data is stored on the host at `DATA_PATH` (set in `srcs/.env`), mounted as bind volumes:

| Volume | Host path | Contains |
|--------|-----------|----------|
| `wp-db` | `$DATA_PATH/db` | MariaDB data files |
| `wp-files` | `$DATA_PATH/wordpress` | WordPress core + uploads |

Data survives `make down` and `make restart`. Only `make fclean` removes it from disk.

```bash
docker volume inspect wp-db     # confirm mount path
docker volume inspect wp-files
```

---

## Resetting

```bash
make fclean   # removes everything: containers, images, volumes, host directories
make          # rebuild from zero
```

To reset Docker state before evaluation:

```bash
make eval
```
