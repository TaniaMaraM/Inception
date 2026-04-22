# Inception — Complete Guide
**42 School | Login: tmarcos | Domain: tmarcos.42.fr**

---

## Table of Contents
1. [Repository Review](#1-repository-review)
2. [VM Setup Guide](#2-vm-setup-guide)
3. [Evaluation Cheatsheet](#3-evaluation-cheatsheet)

---

## 1. Repository Review

| # | Requirement | Status | Detail |
|---|-------------|--------|--------|
| 1 | Makefile at repository root | ✅ PASS | Makefile present with all, down, clean, fclean, re, eval targets |
| 2 | `srcs/` folder at root with `docker-compose.yml` | ✅ PASS | All config files inside srcs/ as required by the subject |
| 3 | No `network: host` in docker-compose.yml | ✅ PASS | Uses bridge network driver only |
| 4 | No `links:` in docker-compose.yml | ✅ PASS | Services communicate via Docker internal DNS |
| 5 | No `--link` in any script or Makefile | ✅ PASS | Not found anywhere in the repository |
| 6 | `networks:` defined in docker-compose.yml | ✅ PASS | "inception" bridge network defined, attached to all 3 services |
| 7 | One Dockerfile per service (3 total) | ✅ PASS | mariadb/, wordpress/, nginx/ each have their own Dockerfile |
| 8 | No empty Dockerfiles | ✅ PASS | All three Dockerfiles have valid, non-empty content |
| 9 | `FROM debian:bookworm` in all Dockerfiles | ✅ PASS | All 3 services use FROM debian:bookworm (penultimate stable) |
| 10 | Docker image names match service names | ✅ PASS | `image: mariadb`, `image: wordpress`, `image: nginx` |
| 11 | Port 443 only exposed (no port 80) | ✅ PASS | Only `ports: "443:443"` in nginx; port 80 absent from compose |
| 12 | TLSv1.2 and TLSv1.3 only | ✅ PASS | `ssl_protocols TLSv1.2 TLSv1.3;` in nginx/conf/default.conf |
| 13 | No `tail -f` or infinite loops in entrypoints | ✅ PASS | All entrypoints use `exec` to become PID 1 — clean shutdown |
| 14 | No NGINX in WordPress Dockerfile | ✅ PASS | WordPress container only installs php8.2-fpm and wp-cli |
| 15 | No NGINX in MariaDB Dockerfile | ✅ PASS | MariaDB container only installs mariadb-server |
| 16 | Admin username without "admin" or "Admin" | ✅ PASS | `WP_ADMIN_USER=tmarcos_wp` — no "admin" substring |
| 17 | Two WordPress users created | ✅ PASS | tmarcos_wp (administrator) + tmarcos (subscriber) |
| 18 | Volumes path in `/home/tmarcos/data/` | ✅ PASS | `DATA_PATH=/home/tmarcos/data` in .env.example |
| 19 | `.env` not committed to repository | ✅ PASS | `srcs/.env` is in `.gitignore` — only `.env.example` is tracked |
| 20 | `server_name` in nginx.conf | ⚠️ NOTE | Hardcoded as `tmarcos.42.fr` — intentional and correct for this login |

> **Result: 19/20 checks pass. The one warning is intentional and will not fail evaluation.**

---

## 2. VM Setup Guide

> All commands run **inside the Debian VM terminal**. You need sudo privileges and internet access on the VM.

---

### Step 1 — Start your VM and open a terminal

Boot Debian in VirtualBox. Log in with your user credentials. Open a terminal (right-click the desktop, or find it in the Applications menu).

---

### Step 2 — Update the system packages

Always do this first. It downloads the latest package lists and upgrades what is already installed.

```bash
sudo apt-get update && sudo apt-get upgrade -y
```

---

### Step 3 — Install required tools

- `git` — to clone your repository  
- `curl` — to download Docker's GPG key  
- `ca-certificates` and `gnupg` — for secure package verification

```bash
sudo apt-get install -y ca-certificates curl gnupg git
```

---

### Step 4 — Add Docker's official GPG key

A GPG key lets `apt` verify that downloaded Docker packages are authentic and not tampered with. Think of it as a digital signature check.

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

---

### Step 5 — Add Docker's apt repository

This tells Debian's package manager where to find Docker packages. Without this, `apt-get install docker-ce` would fail with "package not found".

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

---

### Step 6 — Install Docker Engine and Docker Compose

This installs Docker itself, plus Docker Compose as a plugin (used as `docker compose`, not `docker-compose`).

```bash
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

---

### Step 7 — Add your user to the docker group

Without this, every docker command needs `sudo`. After running this, **you must log out and log back in** — the group membership only takes effect in a new session.

```bash
sudo usermod -aG docker $USER
# Now log out (exit terminal / log out of the desktop session) and log back in!
```

---

### Step 8 — Verify Docker is working

After logging back in, test that Docker works without `sudo`.

```bash
docker --version
docker compose version
docker run hello-world
```

If `hello-world` prints a success message, Docker is correctly installed.

---

### Step 9 — Clone your repository

Clone into your home directory. Replace the URL with your actual repository URL from 42 intra or GitHub.

```bash
cd ~
git clone https://github.com/YOUR_USERNAME/Inception.git
cd Inception
```

---

### Step 10 — Create the .env file

The `.env` file holds all credentials and is **never committed to Git** (it is in `.gitignore`). You must create it manually every time from the example template.

```bash
cp srcs/.env.example srcs/.env

# Verify the file was created:
cat srcs/.env
```

---

### Step 11 — Check and edit the .env file if needed

For login `tmarcos` the example values are already correct. If you need to change anything, use `nano`. Press `Ctrl+X`, then `Y`, then `Enter` to save.

```bash
nano srcs/.env
```

The file must contain exactly this:

```env
LOGIN=tmarcos
DOMAIN_NAME=tmarcos.42.fr
DATA_PATH=/home/tmarcos/data

MYSQL_HOSTNAME=mariadb
MYSQL_DATABASE=tmarcosdb
MYSQL_USER=tmarcos
MYSQL_PASSWORD=tmarcos123
MYSQL_ROOT_PASSWORD=tmarcos123

WP_TITLE=tmarcos Inception
WP_ADMIN_USER=tmarcos_wp
WP_ADMIN_PASSWORD=tmarcos123
WP_ADMIN_EMAIL=admin@tmarcos.42.fr

WP_USER=tmarcos
WP_USER_PASSWORD=tmarcos123
WP_USER_EMAIL=tmarcos@gmail.com
```

---

### Step 12 — Add your domain to /etc/hosts

This makes the browser on your VM resolve `tmarcos.42.fr` to `127.0.0.1` (your own machine). Without this, the browser cannot find the server because it is not a real public domain.

```bash
echo "127.0.0.1 tmarcos.42.fr" | sudo tee -a /etc/hosts

# Verify it was added:
grep tmarcos /etc/hosts
```

---

### Step 13 — Run the project with make

The Makefile creates the data directories, builds all Docker images from scratch, and starts the containers. **The first run takes 5–10 minutes** — it downloads Debian and builds all 3 images.

```bash
make

# To watch the logs in real time:
make logs
# Press Ctrl+C to stop following logs (containers keep running)
```

---

### Step 14 — Verify everything is running

Check that all 3 containers are running, then open the browser.

```bash
docker compose -p inception ps
# You should see 3 services all with status "running":
# inception-mariadb-1    running
# inception-wordpress-1  running
# inception-nginx-1      running
```

Open **Firefox or Chromium on the VM** and go to:

```
https://tmarcos.42.fr
```

Accept the self-signed certificate warning. You should see the WordPress site — **not** the WordPress installation page.

---

### What is actually running?

| Container | Port | Role |
|-----------|------|------|
| `inception-mariadb-1` | 3306 (internal only) | Database — stores all WordPress data in `/home/tmarcos/data/db` |
| `inception-wordpress-1` | 9000 (internal only) | PHP-FPM — runs WordPress, files in `/home/tmarcos/data/wordpress` |
| `inception-nginx-1` | 443 (public) | HTTPS entry point — TLS termination + proxy to php-fpm |

---

## 3. Evaluation Cheatsheet

### Critical Rule — Creating .env During Evaluation

> **The evaluator must watch you create this file from scratch.** This proves credentials are not hardcoded in the repository.

```bash
# Step 1 — Copy the template (the evaluator watches you do this):
cp srcs/.env.example srcs/.env

# Step 2 — Show the evaluator the contents:
cat srcs/.env

# Step 3 — Confirm .env is not in git:
git show HEAD:srcs/.env
# Expected: "fatal: Path 'srcs/.env' does not exist in 'HEAD'" — this is CORRECT
```

---

### Quick Command Reference

| Command | What it checks |
|---------|----------------|
| `make eval` | Pre-eval cleanup — wipe all Docker state |
| `cp srcs/.env.example srcs/.env` | Create .env from template |
| `make` | Build images and start all containers |
| `docker compose -p inception ps` | Verify all 3 containers are running |
| `docker network ls` | Verify `inception_inception` network exists |
| `docker network inspect inception_inception` | Show network details and connected containers |
| `docker volume ls` | List volumes (`inception_wp-db`, `inception_wp-files`) |
| `docker volume inspect inception_wp-db` | Verify MariaDB volume → `/home/tmarcos/data/db` |
| `docker volume inspect inception_wp-files` | Verify WordPress volume → `/home/tmarcos/data/wordpress` |
| `curl -kI https://tmarcos.42.fr` | Test HTTPS works (should return HTTP headers) |
| `curl http://tmarcos.42.fr` | Test HTTP is blocked (should fail — connection refused) |
| `openssl s_client -connect tmarcos.42.fr:443 -tls1_2 < /dev/null` | Verify TLSv1.2 is accepted |
| `openssl s_client -connect tmarcos.42.fr:443 -tls1_3 < /dev/null` | Verify TLSv1.3 is accepted |
| `openssl s_client -connect tmarcos.42.fr:443 -tls1_1 < /dev/null` | Verify TLSv1.1 is REJECTED |
| `docker exec -it inception-mariadb-1 mariadb -u tmarcos -ptmarcos123 tmarcosdb` | Connect to MariaDB |
| `SHOW DATABASES;` | Show databases (inside MariaDB shell) |
| `SHOW TABLES;` | Show WordPress tables — must not be empty |
| `SELECT COUNT(*) FROM wp_posts;` | Count posts in the database |

---

### Evaluation Steps in Order

#### Step 0 — Pre-evaluation cleanup (MANDATORY — run this first)

```bash
# Using the Makefile target:
make eval

# Or the raw command from the evaluation sheet:
docker stop $(docker ps -qa) 2>/dev/null; docker rm $(docker ps -qa) 2>/dev/null; docker rmi -f $(docker images -qa) 2>/dev/null; docker volume rm $(docker volume ls -q) 2>/dev/null; docker network rm $(docker network ls -q) 2>/dev/null
```

---

#### Step 1 — Clone, create .env, and run

```bash
git clone <your-repo-url> && cd Inception
cp srcs/.env.example srcs/.env
make
```

---

#### Step 2 — Verify containers are running

```bash
docker compose -p inception ps
# Expected: 3 services all showing "running"
```

---

#### Step 3 — Check the Docker network

```bash
docker network ls
# Must show: inception_inception

docker network inspect inception_inception
# Shows all 3 containers connected to this network
```

---

#### Step 4 — Verify HTTPS works and HTTP is blocked

```bash
# Make sure the domain resolves:
grep tmarcos.42.fr /etc/hosts || echo "127.0.0.1 tmarcos.42.fr" | sudo tee -a /etc/hosts

# HTTPS must work:
curl -kI https://tmarcos.42.fr

# HTTP must FAIL — port 80 is not open:
curl http://tmarcos.42.fr
# Expected: "curl: (7) Failed to connect to tmarcos.42.fr port 80: Connection refused"

# In browser on the VM:
# https://tmarcos.42.fr  →  WordPress site (NOT the installation page)
```

---

#### Step 5 — Verify TLS version

```bash
# TLS 1.2 must be ACCEPTED:
openssl s_client -connect tmarcos.42.fr:443 -tls1_2 < /dev/null 2>&1 | grep -E "Protocol|CONNECTED|Cipher"

# TLS 1.3 must be ACCEPTED:
openssl s_client -connect tmarcos.42.fr:443 -tls1_3 < /dev/null 2>&1 | grep -E "Protocol|CONNECTED|Cipher"

# TLS 1.1 must be REJECTED:
openssl s_client -connect tmarcos.42.fr:443 -tls1_1 < /dev/null 2>&1 | grep -E "error|alert|handshake"
# Expected: "no protocols available" or "ssl handshake failure"
```

---

#### Step 6 — Inspect volumes

```bash
docker volume ls
# Must show: inception_wp-db and inception_wp-files

docker volume inspect inception_wp-db
# Look for: "Mountpoint": "/home/tmarcos/data/db"

docker volume inspect inception_wp-files
# Look for: "Mountpoint": "/home/tmarcos/data/wordpress"
```

---

#### Step 7 — Connect to MariaDB and check the database

```bash
docker exec -it inception-mariadb-1 mariadb -u tmarcos -ptmarcos123 tmarcosdb

# Inside the MariaDB shell:
SHOW DATABASES;
SHOW TABLES;
SELECT COUNT(*) FROM wp_posts;
SELECT user_login, user_email FROM wp_users;
exit
```

The database must not be empty. You should see WordPress tables (`wp_posts`, `wp_users`, etc.).

---

#### Step 8 — WordPress admin login

Open `https://tmarcos.42.fr/wp-admin` in the browser.

| Field | Value |
|-------|-------|
| Username | `tmarcos_wp` |
| Password | `tmarcos123` |

> **The evaluator will verify that the admin username does NOT contain "admin" or "Admin".** `tmarcos_wp` passes this check.

The evaluator will:
1. Confirm the admin username has no "admin" substring
2. Check the admin dashboard loads correctly
3. Edit a page and verify the change appears on the site

---

#### Step 9 — Add a comment as the subscriber user

Log out from admin. Then log in as:

| Field | Value |
|-------|-------|
| Username | `tmarcos` |
| Password | `tmarcos123` |
| Role | subscriber |

Navigate to any WordPress post and add a comment. The evaluator will verify this works.

---

#### Step 10 — Persistence test (VM reboot)

```bash
# Reboot the VM:
sudo reboot

# After it restarts, open a terminal and:
cd ~/Inception
make

# Open https://tmarcos.42.fr in browser.
# The comment you added and the page you edited must still be there.
# This proves the Docker volumes work correctly.
```

---

### Theory Questions — Be Ready to Answer

**Q: How does Docker work?**  
Containers share the host OS kernel but are isolated via Linux namespaces (network, PID, filesystem) and cgroups (CPU/RAM limits). An image is a read-only stack of layers; a container adds a writable layer on top. Containers are NOT VMs — they have no guest OS.

**Q: Docker image with compose vs without?**  
Without compose: you run `docker build` and `docker run` manually with long flags for ports, volumes, env vars, networks. With compose: you declare everything in a YAML file and one command (`docker compose up`) builds and starts all services with correct dependencies.

**Q: Benefits of Docker vs VMs?**  
Containers are much lighter — no guest OS means they start in seconds, use less RAM and disk. Images are portable (same image runs anywhere Docker runs). Isolation is sufficient for development and deployment. VMs offer stronger isolation but with much higher overhead.

**Q: Why this directory structure?**  
The subject requires `srcs/` for all config files. Each service in `requirements/` has its own Dockerfile — one per service. Volumes in `/home/tmarcos/data/` persist data between container restarts. `.env` holds secrets and is never committed to Git.

**Q: What is a Docker network?**  
A virtual network that lets containers communicate using service names as DNS hostnames. In this project, all services are on the "inception" network so `wordpress` can reach `mariadb` and `nginx` can reach `wordpress:9000`. They are isolated from other Docker projects.

**Q: How to log into MariaDB?**  
Use `docker exec` to run a command inside the running container:  
```bash
docker exec -it inception-mariadb-1 mariadb -u tmarcos -ptmarcos123 tmarcosdb
```  
The `-it` flag gives you an interactive terminal. The container name comes from `docker compose ps`.
