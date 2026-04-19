# Plan: Inception — Docker Infrastructure

> Source PRD: inception.pdf (42 school project v5.2)
> Evaluation sheet: Inception_evaluation.pdf

## Architectural decisions

Durable decisions that apply across all phases:

- **Entry point**: NGINX is the ONLY container exposed externally, on port 443 (TLS 1.2/1.3). Port 80 is rejected.
- **Internal ports**: WordPress php-fpm listens on port 9000. MariaDB listens on port 3306. Neither is exposed to host.
- **Base image**: `debian:bookworm` (penultimate stable) for all containers. No `latest` tag ever.
- **Network**: One custom docker bridge network named `inception`. No `network: host`, no `--link`.
- **Volumes**: Two named Docker volumes (`wp-db`, `wp-files`). Data stored at `/home/login/data/` on the VM host. Bind mounts are forbidden for these.
- **Secrets**: All passwords/credentials live in `secrets/` text files (gitignored) and/or `.env` (gitignored). Never in Dockerfiles.
- **Restart policy**: `restart: unless-stopped` (or `on-failure`) on every container.
- **Domain**: `login.42.fr` resolves to VM's local IP via `/etc/hosts` on the VM.
- **WordPress admin**: Admin username MUST NOT contain "admin" or "Admin".

---

## Phase 1: Understand Docker + scaffold the project

> **Evaluation section covered**: Project overview, General instructions
> **Teaching focus**: What is a container? How does it differ from a VM?

### Concepts to understand before writing a single line

Docker uses Linux kernel features your C programs can also call directly:
- `clone(CLONE_NEWPID | CLONE_NEWNS | CLONE_NEWNET)` — creates an isolated process with its own PID namespace, filesystem namespace, and network namespace.
- `chroot` + OverlayFS — gives the container its own filesystem view (read-only image layers + writable top layer).
- `cgroups` — limits CPU and memory the container can use.

A **Dockerfile** is a recipe to build an image (frozen filesystem snapshot). A **container** is a running instance of that image.

**Why not a VM?** A VM boots a full kernel, emulates hardware, uses gigabytes of RAM. A container shares the host kernel — startup is milliseconds, overhead is minimal. Tradeoff: less isolation than a VM.

### What to build

Create the full directory structure, Makefile skeleton, `.env` template, `secrets/` folder, and `.gitignore`. No containers yet — just the scaffolding that everything else will plug into.

```
Inception/
├── Makefile
├── secrets/
│   ├── db_password.txt
│   ├── db_root_password.txt
│   └── credentials.txt
└── srcs/
    ├── .env
    ├── docker-compose.yml        (empty stub)
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        └── mariadb/
            ├── Dockerfile
            ├── conf/
            └── tools/
```

### Acceptance criteria

- [ ] Directory structure matches the spec exactly
- [ ] `.gitignore` ignores `secrets/`, `srcs/.env`, and `**/data/`
- [ ] `secrets/*.txt` files exist locally but are NOT committed to git
- [ ] `srcs/.env` has placeholders for: `DOMAIN_NAME`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_ROOT_PASSWORD`, `WP_ADMIN_USER` (no "admin"), `WP_ADMIN_EMAIL`, `WP_USER`, `WP_USER_PASSWORD`
- [ ] `Makefile` has `all`, `down`, `clean`, `fclean`, `re` targets (stubs ok for now)
- [ ] She can explain: "What is a container vs a VM?" and "What is an image?"

---

## Phase 2: MariaDB container — first working service

> **Evaluation section covered**: MariaDB and its volume
> **Teaching focus**: What is a Dockerfile? What is PID 1? What is a named volume?

### Concepts to understand

**Dockerfile** = instructions to build an image. Think of it like a shell script that runs once at build time, layer by layer. Each `RUN` creates a new filesystem layer (like a git commit).

**PID 1 problem**: In a container, your process starts as PID 1. The kernel sends `SIGTERM` to PID 1 when stopping. If PID 1 is `bash` or `tail -f` instead of `mysqld`, your database never receives the shutdown signal — data can corrupt. Always run the real daemon as PID 1 (use `exec` in shell scripts, or `CMD ["mysqld"]` directly).

**Named volume** = Docker-managed storage that lives at `/var/lib/docker/volumes/` on the host (we'll configure it to map to `/home/login/data/db`). When the container is deleted, the volume survives.

### What to build

A `mariadb/Dockerfile` that:
1. Starts `FROM debian:bookworm`
2. Installs `mariadb-server`
3. Has an `ENTRYPOINT` script that initializes the DB (creates database, user, sets passwords from env vars) **only on first run** (check if data directory is empty)
4. Runs `mysqld` as PID 1 in the foreground

Wire it into `docker-compose.yml` with:
- The named volume `wp-db` mounted at `/var/lib/mysql`
- All credentials from `.env` via `environment:`
- `restart: unless-stopped`

Test: `docker compose up mariadb` → `docker exec -it <container> mariadb -u $MYSQL_USER -p` logs in and shows the database.

### Acceptance criteria

- [ ] `mariadb/Dockerfile` starts with `FROM debian:bookworm` (not `latest`)
- [ ] No passwords hardcoded in Dockerfile
- [ ] ENTRYPOINT script uses `exec mysqld` (not background `mysqld &`)
- [ ] No `tail -f`, `sleep infinity`, or `while true` anywhere
- [ ] `docker compose ps` shows container is Up (not Restarting)
- [ ] `docker volume ls` shows `wp-db` volume
- [ ] `docker volume inspect wp-db` shows path under `/home/login/data/`
- [ ] Can log into MariaDB: `docker exec -it mariadb mariadb -u $MYSQL_USER -p`
- [ ] Database is not empty (has the wordpress DB and user)
- [ ] She can explain: "What is PID 1 and why does it matter?"

---

## Phase 3: WordPress + php-fpm container

> **Evaluation section covered**: WordPress with php-fpm and its volume
> **Teaching focus**: What is php-fpm? What is a FastCGI process? How do containers talk to each other?

### Concepts to understand

**php-fpm** (FastCGI Process Manager) = a PHP interpreter that listens on a socket (port 9000) and processes PHP scripts on demand. It does NOT serve HTTP — it only runs PHP. NGINX will forward `.php` requests to it.

Think of it like a function call across a network: NGINX receives the HTTP request, sees it needs PHP, sends it to php-fpm via a socket, php-fpm runs the PHP code, returns HTML to NGINX, NGINX sends it back to the browser.

**Container-to-container networking**: In the Docker network, containers can reach each other by service name (Docker's internal DNS). WordPress can reach MariaDB at hostname `mariadb:3306`. This is like having `/etc/hosts` entries added automatically.

### What to build

A `wordpress/Dockerfile` that:
1. Starts `FROM debian:bookworm`
2. Installs `php-fpm`, `php-mysql`, and `wget`
3. Has an ENTRYPOINT script that:
   - Downloads `wp-cli` to configure WordPress
   - Runs `wp core install` with credentials from env vars (sets up the DB tables)
   - Creates the second WP user (non-admin)
   - **Ensures admin username does NOT contain "admin"**
4. Runs `php-fpm` in foreground as PID 1

Wire into `docker-compose.yml` with:
- Named volume `wp-files` at `/var/www/html`
- Depends on `mariadb`
- Port 9000 exposed internally (NOT to host)

### Acceptance criteria

- [ ] `wordpress/Dockerfile` has no NGINX inside
- [ ] php-fpm listens on port 9000
- [ ] WordPress is fully installed (no installation wizard appears when browsing)
- [ ] Two users exist: one admin (username without "admin"), one regular user
- [ ] `docker volume ls` shows `wp-files`
- [ ] `docker volume inspect wp-files` shows path under `/home/login/data/`
- [ ] Can add a comment as the regular WordPress user
- [ ] From admin dashboard, can edit a page and changes show on the site
- [ ] She can explain: "What is php-fpm and why is it separate from NGINX?"

---

## Phase 4: NGINX container with TLS

> **Evaluation section covered**: NGINX with SSL/TLS, Docker Basics
> **Teaching focus**: What is TLS? What is a self-signed certificate? What is a reverse proxy?

### Concepts to understand

**TLS** (Transport Layer Security) = encryption layer on top of TCP. The browser and server do a "handshake" — they negotiate a cipher, the server proves its identity with a certificate, then all data is encrypted. TLS 1.2/1.3 are the modern secure versions. Older versions (SSLv3, TLS 1.0/1.1) have known vulnerabilities.

**Self-signed certificate** = a certificate you sign yourself instead of paying a Certificate Authority. Browsers will show a warning ("Your connection is not private") because they don't trust your CA. For this project that's fine — the evaluator will click through it.

**Reverse proxy** = NGINX sits in front of WordPress. The browser talks to NGINX (it doesn't know WordPress exists). NGINX forwards requests to php-fpm for PHP files, serves static files itself. Think of it like a receptionist who routes calls.

**Why only port 443?** Port 80 is plain HTTP (unencrypted). The project requires HTTPS only — NGINX must not listen on 80, or must redirect to 443.

### What to build

A `nginx/Dockerfile` that:
1. Starts `FROM debian:bookworm`
2. Installs `nginx` and `openssl`
3. Generates a self-signed TLS certificate at build time (or via entrypoint)
4. Has an `nginx.conf` that:
   - Listens on 443 only with `ssl_protocols TLSv1.2 TLSv1.3`
   - Serves `login.42.fr`
   - Passes `.php` requests to `wordpress:9000` via FastCGI
5. Runs `nginx -g 'daemon off;'` as PID 1

Wire into `docker-compose.yml` with:
- Port `443:443` published to host
- **No port 80**

### Acceptance criteria

- [ ] `nginx/Dockerfile` exists and is not empty
- [ ] Container starts with `docker compose ps` showing Up
- [ ] Accessing via `http://` (port 80) fails / connection refused
- [ ] `https://login.42.fr` opens the WordPress site (not the install wizard)
- [ ] Browser shows TLS warning (self-signed) — click through — site loads
- [ ] TLS version is 1.2 or 1.3 (verify with `openssl s_client -connect login.42.fr:443`)
- [ ] She can explain: "What is TLS and what is a self-signed certificate?"
- [ ] She can explain: "What is a reverse proxy?"

---

## Phase 5: docker-compose + network + final wiring

> **Evaluation section covered**: Docker Network, General instructions, Simple setup
> **Teaching focus**: What is a docker network? How does docker-compose wire everything?

### Concepts to understand

**Docker bridge network** = a virtual Ethernet switch inside the host. Each container gets a virtual NIC (like `eth0`) connected to this switch. Containers on the same network can talk to each other by service name. The host can only reach containers through published ports.

Under the hood, Docker creates a `veth` pair (virtual Ethernet pair) — like a pipe: one end goes into the container's network namespace, the other connects to a bridge (`docker0` or your custom bridge). This is pure Linux networking, no virtualization.

**Why no `network: host`?** With `network: host`, the container shares the host's network stack — no isolation. Your NGINX would bind directly to the host's port 443, bypassing Docker's networking entirely. Forbidden for this project.

### What to build

Complete `docker-compose.yml` with:
- All three services using custom `inception` network
- No `network: host`, no `links:`, no `--link`
- `restart: unless-stopped` on all containers
- Volumes section declaring `wp-db` and `wp-files` as named volumes with `driver_opts` pointing to `/home/login/data/`
- All credentials injected via `env_file: .env`

Makefile targets:
- `make` / `make all` → `docker compose up --build -d`
- `make down` → `docker compose down`
- `make clean` → stop + remove containers + volumes
- `make fclean` → clean + remove images
- `make re` → fclean + all

### Acceptance criteria

- [ ] `docker-compose.yml` has a `networks:` section
- [ ] `docker network ls` shows the `inception` network after `make`
- [ ] No `network: host`, no `links:`, no `--link` anywhere
- [ ] `make` starts all 3 containers cleanly with no crash
- [ ] `make down` stops everything cleanly
- [ ] `make re` rebuilds from scratch
- [ ] She can explain: "What is a docker network and how do containers find each other?"
- [ ] She can explain: "What is the difference between docker-compose and running docker by hand?"

---

## Phase 6: Local smoke test (Mac)

> **Evaluation section covered**: Simple setup, Persistence (dry run before VM)
> **Teaching focus**: /etc/hosts, TLS browser warning, Docker file sharing on Mac

### What to build

On the Mac (for development testing):
1. Set `LOGIN=augusto.costa` and `DOMAIN_NAME=augusto.42.fr` in `srcs/.env`
2. Add `/home` to Docker Desktop file sharing: Docker Desktop → Settings → Resources → File Sharing → add `/home`
3. Edit `/etc/hosts` (Mac): `echo "127.0.0.1 augusto.42.fr" | sudo tee -a /etc/hosts`
4. `make` — builds all 3 images and starts containers
5. Open `https://augusto.42.fr` in browser — click through the self-signed cert warning
6. Log in to WordPress admin at `https://augusto.42.fr/wp-admin` with `taniawp` / `taniawppass123`
7. Verify second user `taniareader` exists in Users panel
8. Create a test post, then run `make re` — post survives (volumes not wiped by `re`)

### How to create a WordPress user (evaluator may ask to demo this)

A second user (`taniareader`) is created automatically on first run by the entrypoint. To see it:
```bash
docker exec wordpress wp user list --allow-root
```

To create an additional user manually (via wp-cli in the container):
```bash
docker exec wordpress wp user create newuser newuser@example.com \
  --user_pass=newpass123 --role=subscriber --allow-root
```

To do it via the admin UI: `https://augusto.42.fr/wp-admin` → Users → Add New.

The evaluator rule: **at least 2 users**, admin username must **not** contain "admin" or "Admin".

### Acceptance criteria

- [ ] `https://augusto.42.fr` loads WordPress site (no install wizard)
- [ ] `http://augusto.42.fr` refuses to connect (port 80 not exposed)
- [ ] `https://augusto.42.fr/wp-admin` logs in as `taniawp` successfully
- [ ] `docker exec wordpress wp user list --allow-root` shows 2 users
- [ ] `make fclean` tears everything down; `make` brings it all back
- [ ] `docker volume inspect inception_wp-db` shows device path at `/home/augusto.costa/data/db`

---

## Phase 7: Documentation + evaluation prep

> **Evaluation section covered**: Project overview (verbal explanation), README requirements
> **Teaching focus**: Consolidate understanding, prepare verbal answers

### What to build

**README.md** at repo root with:
- First line italicized: `*This project has been created as part of the 42 curriculum by <login>.*`
- Description section
- Instructions section
- Project description section comparing:
  - VM vs Docker
  - Secrets vs Environment Variables
  - Docker Network vs Host Network
  - Docker Volumes vs Bind Mounts

**USER_DOC.md** at repo root:
- What services the stack provides
- How to start/stop the project
- How to access the website and admin panel
- Where credentials are located
- How to check services are running

**DEV_DOC.md** at repo root:
- How to set up from scratch (prerequisites, secrets, .env)
- Build and launch with Makefile + Docker Compose
- Useful commands to manage containers/volumes
- Where data is stored and how it persists

### Verbal questions to practice answering (the evaluator WILL ask these)

1. "Explain how Docker and docker-compose work" → Containers share host kernel, isolated via namespaces/cgroups. Compose orchestrates multiple containers from a YAML file.
2. "What is the difference between a Docker image used with and without docker-compose?" → Same image either way. Compose just automates running it with the right env, networks, volumes, and restart policy.
3. "What is the benefit of Docker compared to VMs?" → Lighter (shares kernel), faster startup, reproducible environments, less resource overhead.
4. "Explain the directory structure of this project" → srcs/ has compose + .env + requirements/; each service has its own Dockerfile + conf + tools.
5. "Explain docker-network" → Virtual bridge switch; containers on same network reach each other by service name via Docker's internal DNS.
6. "How do you log into the MariaDB database?" → `docker exec -it mariadb mariadb -u $MYSQL_USER -p`

### Acceptance criteria

- [ ] README.md present with all required sections and comparisons
- [ ] USER_DOC.md present and covers all required topics
- [ ] DEV_DOC.md present and covers all required topics
- [ ] All docs written in English
- [ ] She can answer all 6 verbal questions without looking at notes
- [ ] She can walk through each Dockerfile and explain every line
- [ ] She can explain why `tail -f` is forbidden
- [ ] She can explain why no passwords in Dockerfiles

---

## Phase 9: VM deployment

> **Evaluation section covered**: Simple setup, Persistence (for real)
> **Teaching focus**: This is the final submission environment — everything must work here

### What to build

On the 42 VM (after pushing to git and cloning):
1. Clone the repo: `git clone <repo> Inception && cd Inception`
2. Create `srcs/.env` — copy from `.env.example`, set `LOGIN=<her 42 login>` and `DOMAIN_NAME=<login>.42.fr`
3. Add `/etc/hosts` entry: `echo "127.0.0.1 <login>.42.fr" | sudo tee -a /etc/hosts`
4. `make` — builds and starts everything
5. Open `https://<login>.42.fr` in VM browser — click through cert warning
6. Log in as admin, create a post/comment
7. `sudo reboot` then `make` — content must survive

### MariaDB login demo (evaluator will watch this)
```bash
docker exec -it mariadb mariadb -u wpuser -pwpuserpass123 wordpress
# Inside MariaDB:
SHOW TABLES;
SELECT user, host FROM mysql.user;
EXIT
```

### Evaluator's full wipe command (they will run this)
```bash
docker stop $(docker ps -qa)
docker rm $(docker ps -qa)
docker rmi -f $(docker images -qa)
docker volume rm $(docker volume ls -q)
docker network rm $(docker network ls -q) 2>/dev/null
```
After this: `make` must rebuild and restore everything from scratch.

### Acceptance criteria

- [ ] `https://<login>.42.fr` loads WordPress on the VM
- [ ] `http://<login>.42.fr` refused (only 443)
- [ ] MariaDB login demo works live during evaluation
- [ ] Data persists after VM reboot
- [ ] Full wipe + `make re` restores everything
- [ ] `docker volume inspect` shows data at `/home/<login>/data/` on VM host
- [ ] She can answer all verbal questions without notes

---

## Bonus (only after mandatory is perfect)

Each bonus needs its own Dockerfile and runs in its own container.

| Bonus | Port | Notes |
|-------|------|-------|
| Redis | 6379 (internal) | WordPress redis-cache plugin connects to it |
| FTP server | 21 + passive range | Points to `wp-files` volume |
| Static website | e.g. 8080 | Any language except PHP |
| Adminer | e.g. 8080 | DB admin UI, connects to MariaDB |
| Custom service | your choice | Must be able to justify it verbally |
