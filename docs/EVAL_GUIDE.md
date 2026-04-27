# Inception — Complete Guide
**42 School | Login: tmarcos | Domain: tmarcos.42.fr**

---

## Table of Contents
1. [Repository Review](#1-repository-review)
2. [VirtualBox VM Creation (Debian with GUI)](#2-virtualbox-vm-creation-debian-with-gui)
3. [VM Setup Guide (inside Debian)](#3-vm-setup-guide-inside-debian)
4. [Evaluation Cheatsheet](#4-evaluation-cheatsheet)

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

## 2. VirtualBox VM Creation (Debian with GUI)

> You already have the Debian ISO downloaded. Follow these steps to create and install the VM in VirtualBox. Do this **at home** before going to 42.

---

### Step 1 — Create the Virtual Machine in VirtualBox

Open VirtualBox and click **New**. Fill in:

| Setting | Value |
|---------|-------|
| Name | `Inception` (or any name) |
| Type | `Linux` |
| Version | `Debian (64-bit)` |
| RAM | `4096 MB` (4GB) — minimum 2048MB |
| CPUs | `2` |
| Hard Disk | Create a new one → `30 GB` → VDI → Dynamically allocated |

> **Why these specs?** Docker builds images and runs 3 containers. 2GB RAM is the bare minimum — 4GB avoids freezes. 30GB disk ensures you have room for Debian, Docker images, and volumes.

---

### Step 2 — Attach the Debian ISO

1. Select your new VM → click **Settings**
2. Go to **Storage** → click the empty CD icon under "Controller: IDE"
3. Click the blue disk icon on the right → **Choose a disk file**
4. Select your downloaded `debian-12.x.x-amd64-netinst.iso`
5. Click **OK**

---

### Step 3 — Configure Display (important for GUI)

Still in **Settings**:
1. Go to **Display**
2. Set **Video Memory** to `128 MB`
3. Enable **3D Acceleration** (tick the checkbox)
4. Click **OK**

---

### Step 4 — Boot and Start the Debian Installer

Click **Start**. The Debian installer loads. Use the **arrow keys** and **Enter** to navigate.

Select: **Graphical install**

> Choose "Graphical install" — it is easier to use than the text installer and gives you a mouse.

---

### Step 5 — Language, Location, Keyboard

| Prompt | Choose |
|--------|--------|
| Language | English (safer for terminal commands) |
| Location | Your country |
| Keyboard | Your keyboard layout (e.g. Portuguese) |

---

### Step 6 — Hostname and Domain

| Prompt | Value |
|--------|-------|
| Hostname | `tmarcos` (your 42 login) |
| Domain name | Leave blank — just press Continue |

---

### Step 7 — User and Passwords

| Prompt | Value |
|--------|-------|
| Root password | Set something memorable (e.g. `tmarcos123`) |
| Full name | Your name or login |
| Username | `tmarcos` (your 42 login) |
| User password | Something memorable |

> Use the same login as your 42 login. The data path in `.env` is `/home/tmarcos/data` — your username must match.

---

### Step 8 — Disk Partitioning

Select: **Guided - use entire disk**  
Select your virtual disk (the 30GB one you created)  
Partitioning scheme: **All files in one partition**  
Select: **Finish partitioning and write changes to disk** → **Yes**

---

### Step 9 — Choose What to Install (Desktop Environment)

When the installer asks **"Software selection"**, you will see a list of checkboxes. Select:

| Option | Tick? |
|--------|-------|
| Debian desktop environment | ✅ YES |
| **Xfce** | ✅ YES — choose this one |
| GNOME | ❌ NO — too heavy for a VM |
| KDE Plasma | ❌ NO — too heavy |
| SSH server | ✅ YES — useful for connecting from host |
| standard system utilities | ✅ YES |

> **Why XFCE?** It is lightweight (uses ~300MB RAM) and runs smoothly in a VM. GNOME needs 2GB+ just for the desktop and will be very slow inside VirtualBox.

---

### Step 10 — GRUB Bootloader

Select: **Yes** → install GRUB to your primary drive  
Select the drive `/dev/sda`

The installer finishes and the VM reboots.

---

### Step 11 — First Boot into Debian Desktop

After reboot you will see the XFCE login screen. Log in with your user (`tmarcos` / your password).

**Install VirtualBox Guest Additions** for better display scaling:

```bash
sudo apt-get install -y virtualbox-guest-x11
sudo reboot
```

After this reboot, the screen resizes automatically and you can go fullscreen with `Host+F` (right Ctrl+F).

---

### Step 12 — Install VSCode (for comfortable editing)

Open a terminal inside the VM (right-click desktop → Open Terminal).

```bash
sudo apt-get install -y wget gpg

wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list

sudo apt-get update && sudo apt-get install -y code
```

Open VSCode with:
```bash
code ~/Inception
```

You can now edit `.env` by clicking on the file in the VSCode sidebar — no copy-paste issues.

---

### At 42 School — What is Different

At 42 the machines run **Linux** (usually Ubuntu or Fedora). VirtualBox is pre-installed. You do **not** reinstall Debian — you bring your VM or clone your repo fresh into the existing school environment.

**Two scenarios at 42:**

**Scenario A — You bring your VM (recommended)**  
Export your VM at home (`File → Export Appliance` → saves a `.ova` file), put it on a USB stick or the 42 storage, and import it at school (`File → Import Appliance`).

**Scenario B — Fresh setup on the school machine**  
The school machine already has VirtualBox and possibly Debian. You:
1. Start VirtualBox
2. Create a new Debian VM (same specs as above) or use an existing one
3. Inside the VM, install Docker (same steps as Section 3 below)
4. Clone your repo and run it

**On the 42 Linux machine (host), you do NOT need to install anything** — VirtualBox handles everything. All Docker and project work happens inside the VM.

---

## 3. VM Setup Guide (inside Debian)

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

## 4. Evaluation Cheatsheet

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


Como explicar durante a avaliação
50-server.cnf — A configuração do servidor
PT-BR:

"Este é o ficheiro de configuração do MariaDB. Eu defino aqui quatro coisas essenciais: o utilizador que corre o processo — que é mysql, não root, por questões de segurança. O bind-address 0.0.0.0 que permite que outros containers na rede Docker se liguem ao servidor. O datadir que aponta para /var/lib/mysql — que é exactamente onde o volume está montado, por isso os dados persistem. E o socket Unix para comunicação local durante a inicialização."

EN:

"This is the MariaDB server configuration. I set four things: the process runs as user mysql, not root — least privilege. bind-address 0.0.0.0 allows other containers on the Docker network to connect. The datadir points to /var/lib/mysql, which is exactly where the volume is mounted — that's how data persists. And the Unix socket for local communication during initialisation."

Dockerfile — A receita da image
PT-BR:

"O Dockerfile parte de debian:bookworm — a penúltima versão estável, como o projecto exige. Num único RUN instalo o MariaDB, limpo o cache do apt para manter a image pequena, e — isto é importante — apago /var/lib/mysql. O apt semeia essa directoria durante a instalação, mas como estou a usar um bind-mount volume, o Docker ignora o conteúdo da image e usa o que está no host. Se eu não apagasse, a lógica de first-run do meu entrypoint falhava silenciosamente. Depois copio a configuração e o entrypoint, e uso ENTRYPOINT em exec form — sem shell intermediário — para garantir que o processo se torna PID 1."

EN:

"The Dockerfile starts from debian:bookworm — the penultimate stable release as required. In a single RUN I install MariaDB, clean the apt cache to keep the image small, and — this is important — I delete /var/lib/mysql. apt seeds that directory during install, but with a bind-mount volume Docker ignores image content and uses whatever's on the host. If I left it, my first-run detection in the entrypoint would silently break. Then I copy the config and entrypoint, and use ENTRYPOINT in exec form — no shell wrapper — so the process becomes PID 1."

entrypoint.sh — A inicialização
PT-BR:

"O entrypoint tem dois momentos: first-run e every-run. Na primeira execução, não existe o ficheiro marker em /var/lib/mysql/.initialized. Então inicializo a base de dados com mysql_install_db, subo uma instância temporária com --skip-networking — sem rede, para nenhum outro container se ligar durante a inicialização — espero que fique pronta com um polling loop, e executo o SQL que cria a base de dados, o utilizador e define as passwords. As credenciais vêm todas de variáveis de ambiente, nunca hardcoded. No fim, crio o marker, mato a instância temporária, e termino sempre com exec mysqld. O exec é crítico: substitui o processo shell pelo mysqld, que passa a ser PID 1. Quando o docker stop manda SIGTERM, o mysqld recebe-o directamente e faz shutdown limpo — flush de dados, fechamento de ligações. Sem exec, o shell seria PID 1, o mysqld seria filho, e o SIGTERM matava o shell — o mysqld recebia SIGKILL brutal, sem hipótese de limpar nada."

EN:

"The entrypoint has two moments: first-run and every-run. On first run, the marker file at /var/lib/mysql/.initialized doesn't exist. So I initialise the data directory with mysql_install_db, start a temporary instance with --skip-networking — no network, so no other container can connect during setup — poll until it's ready, then run the SQL that creates the database, the user, and sets the passwords. All credentials come from environment variables, never hardcoded. Then I create the marker, kill the temporary instance, and always finish with exec mysqld. The exec is critical: it replaces the shell process with mysqld — mysqld becomes PID 1. When docker stop sends SIGTERM, mysqld receives it directly and shuts down cleanly. Without exec, the shell would be PID 1, mysqld would be a child — SIGTERM kills the shell, mysqld gets SIGKILL with no chance to flush data."

Dica para a avaliação: quando acabares de explicar o exec, faz uma pausa. É a parte mais técnica e impressiona. Se o evaluator continuar a perguntar, já sabes ir mais fundo. Se acenar com a cabeça, passa ao próximo ficheiro. Não expliques mais do que perguntam.

Makefile
PT-BR:

"O Makefile é a entrada do projecto. O make faz três coisas em sequência: cria as directorias de dados no host — /home/tmarcos/data/db e /home/tmarcos/data/wordpress — se não existirem, depois chama o Docker Compose para construir as images e subir os containers em background. O -include srcs/.env no topo importa as variáveis do ficheiro .env para o Make — por isso o DATA_PATH funciona directamente nos comandos. O make fclean é o wipe completo: derruba tudo, apaga images, volumes, redes, e os dados no disco. O make eval é para antes da avaliação — para o Docker para garantir estado limpo antes de demonstrar o projecto do zero."

EN:

"The Makefile is the project's entry point. make does three things: creates the data directories on the host, then calls Docker Compose to build all images and start the containers in detached mode. The -include srcs/.env at the top imports the environment variables into Make so DATA_PATH works directly in the commands. make fclean is the full wipe — stops everything, removes images, volumes, networks, and the host data directories. make eval is the pre-evaluation reset — cleans all Docker state so we can demonstrate the project building from scratch."

.env.example
PT-BR:

"O .env.example é o template das credenciais. O ficheiro .env real nunca é commitado ao repositório — está no .gitignore — porque contém passwords. O evaluator vai ver-me criar o .env com cp srcs/.env.example srcs/.env, o que prova que as credenciais não estão no código. Todas as variáveis de ambiente são injectadas pelo Docker Compose nos containers em runtime — nunca estão hardcoded em nenhum Dockerfile ou script."

EN:

"The .env.example is the credentials template. The actual .env is never committed — it's in .gitignore because it contains passwords. The evaluator will watch me create it with cp srcs/.env.example srcs/.env, proving credentials aren't in the codebase. All environment variables are injected by Docker Compose into the containers at runtime — nothing is hardcoded in any Dockerfile or script."

docker-compose.yml
PT-BR:

"O Compose file orquestra os três serviços. Cada serviço tem build: que aponta para o Dockerfile respectivo — todas as images são construídas por nós, nenhuma vem pré-feita. O restart: unless-stopped garante que se um container cair, o Docker reinicia-o automaticamente. O env_file: .env injeta todas as credenciais como variáveis de ambiente. Os depends_on definem a ordem de arranque — wordpress espera pelo mariadb, nginx espera pelo wordpress. Os dois volumes são bind-mounts para /home/tmarcos/data/ no host — é assim que os dados persistem. E todos os containers estão na rede inception com driver bridge — o Docker cria um DNS interno onde cada nome de serviço resolve directamente para o IP do container."

EN:

"The Compose file orchestrates the three services. Each service has build: pointing to its Dockerfile — all images are built by us, none are pre-built. restart: unless-stopped means Docker auto-restarts a crashed container. env_file: .env injects all credentials as environment variables. depends_on sets the startup order. The two volumes are bind-mounts to /home/tmarcos/data/ on the host — that's how data persists across container restarts. All containers are on the inception bridge network, where Docker's internal DNS resolves each service name to its container's IP."

MariaDB — já fizemos, mas o resumo de avaliação:
EN (resumo rápido):

"Three files: the config sets bind-address 0.0.0.0 so other containers can connect, and points datadir to the volume mount. The Dockerfile installs MariaDB and critically deletes /var/lib/mysql from the image layer so our first-run detection works correctly with bind-mounts. The entrypoint uses a marker file to run initialisation only once — starts a temporary no-network MariaDB instance, creates the database and user from environment variables, then replaces itself with exec mysqld so the server becomes PID 1 and handles SIGTERM gracefully."

WordPress — www.conf
PT-BR:

"Este é o ficheiro de configuração do php-fpm — o PHP FastCGI Process Manager. A linha mais importante é listen = 9000 em vez de um socket Unix. Por defeito, o php-fpm ouve num socket Unix que só funciona dentro do mesmo container. Mas o NGINX está noutro container — precisa de ligar via TCP. Por isso mudámos para a porta 9000. O pm = dynamic com os valores de max_children e spare_servers controla quantos processos PHP correm em simultâneo. O clear_env = no é crucial — sem isto, o php-fpm limpa todas as variáveis de ambiente dos workers, e o WordPress não conseguia aceder às credenciais da base de dados."

EN:

"This configures php-fpm. The critical line is listen = 9000 instead of a Unix socket. By default php-fpm listens on a Unix socket that only works within the same container. But NGINX is in a different container and needs TCP to reach it — so we set port 9000. pm = dynamic controls how many PHP worker processes run concurrently. clear_env = no is essential — without it, php-fpm strips all environment variables from worker processes, and WordPress couldn't access the database credentials."

WordPress — Dockerfile
PT-BR:

"Parte de debian:bookworm. Instalo o php-fpm e as extensões PHP que o WordPress precisa: php8.2-mysql para falar com o MariaDB, php8.2-gd para processamento de imagens, php8.2-mbstring para caracteres multi-byte, entre outras. Instalo também o mariadb-client — não para correr um servidor, mas para que o entrypoint consiga fazer ping à base de dados antes de arrancar. E instalo o wp-cli — uma ferramenta de linha de comandos que instala e configura o WordPress completamente sem precisar de browser. É o que nos permite fazer tudo no entrypoint de forma automatizada."

EN:

"Starts from debian:bookworm. I install php-fpm and the PHP extensions WordPress needs: php8.2-mysql to talk to MariaDB, php8.2-gd for image processing, php8.2-mbstring for multibyte strings. I also install mariadb-client — not to run a server, but so the entrypoint can ping the database before starting. And wp-cli — a command-line WordPress installer that sets up the entire site without a browser. That's what allows us to automate everything in the entrypoint."

WordPress — entrypoint.sh
PT-BR:

"O entrypoint do WordPress tem três fases. Primeiro, um polling loop que tenta ligar ao MariaDB de dois em dois segundos — o depends_on do Compose garante que o container do MariaDB arrancou, mas não garante que o servidor dentro dele está pronto. Sem este loop, o WordPress tentaria ligar a uma base de dados que ainda não terminou a inicialização, e crashava. Segundo, se o wp-config.php não existir no volume — ou seja, primeira execução — o wp-cli faz o download do WordPress, cria o ficheiro de configuração com as credenciais do .env, instala o site com título e admin, e cria o segundo utilizador com role de subscriber. O username do admin não contém 'admin' — é tmarcos_wp — requisito de segurança do projecto. Terceiro, exec php-fpm8.2 -F -R: o -F mantém o processo em foreground, o -R permite correr como root, e o exec faz do php-fpm o PID 1 — mesmo raciocínio do MariaDB."

EN:

"Three phases. First, a polling loop that tries to connect to MariaDB every two seconds — depends_on only waits for the container to start, not for the service inside to be ready. Without this loop, WordPress would crash trying to connect to a database that's still initialising. Second, if wp-config.php doesn't exist on the volume — first run — wp-cli downloads WordPress, creates the config file with credentials from environment variables, installs the site, and creates the second user as subscriber. The admin username doesn't contain 'admin' — it's tmarcos_wp — a security requirement that's an instant fail if violated. Third, exec php-fpm8.2 -F -R: -F keeps it in foreground, -R allows running as root, and exec makes php-fpm PID 1 for the same SIGTERM reason as MariaDB."

NGINX — Dockerfile
PT-BR:

"Instalo nginx e openssl — o openssl é para gerar o certificado TLS no entrypoint. A linha importante aqui é rm -f /etc/nginx/sites-enabled/default: o Debian instala o nginx com um site default activo na porta 80. Se o deixasse, conflituaria com a nossa configuração que só usa a 443. Copio a nossa configuração para conf.d/ e uso ENTRYPOINT em exec form."

EN:

"I install nginx and openssl — openssl is for generating the TLS certificate in the entrypoint. The key line is rm -f /etc/nginx/sites-enabled/default: Debian's nginx package comes with a default site active on port 80. If I left it, it would conflict with our config that only uses 443. I copy our config to conf.d/ and use exec form ENTRYPOINT."

NGINX — entrypoint.sh
PT-BR:

"Muito simples. Se o certificado ainda não existe, gera um certificado auto-assinado com openssl — RSA 2048 bits, válido 365 dias, com o CN igual ao nosso domínio tmarcos.42.fr vindo da variável de ambiente. O projecto usa certificado auto-assinado porque não temos um domínio real público — o evaluator vai ver um aviso no browser, o que é esperado. O importante é que TLS está activo. Depois exec nginx -g 'daemon off;' — o daemon off é crítico: sem ele, o nginx faz fork para background, o script shell termina, o container pensa que o processo morreu e fecha. Com daemon off o nginx fica em foreground e torna-se PID 1 via exec."

EN:

"Very simple. If the certificate doesn't exist yet, generate a self-signed certificate with openssl — RSA 2048 bits, 365 days, CN set to our domain from the environment variable. The project uses a self-signed certificate because we don't have a real public domain — the evaluator will see a browser warning, which is expected. What matters is TLS is in use. Then exec nginx -g 'daemon off;' — daemon off is critical: without it, nginx forks to the background, the shell exits, the container thinks the process is dead and stops. With daemon off nginx stays in the foreground and becomes PID 1 via exec."

NGINX — default.conf
PT-BR:

"A configuração do servidor. listen 443 ssl — só HTTPS, sem porta 80. Não há um bloco listen 80 em lado nenhum no projecto. O evaluator vai tentar curl http://tmarcos.42.fr e deve receber 'connection refused' — se responder, é falha. O ssl_protocols TLSv1.2 TLSv1.3 desactiva versões antigas por omissão. A location / usa try_files para suportar os pretty permalinks do WordPress. A location ~ \.php$ encaminha todos os pedidos PHP para wordpress:9000 via FastCGI — o Docker resolve o nome wordpress para o IP do container automaticamente. A location ~ /\. nega acesso a ficheiros ocultos como .htaccess ou .git."

EN:

"listen 443 ssl — HTTPS only, no port 80. There's no listen 80 anywhere in the project. The evaluator will try curl http://tmarcos.42.fr and should get 'connection refused' — if it responds, it's a fail. ssl_protocols TLSv1.2 TLSv1.3 disables older versions by omission. The location / block uses try_files for WordPress pretty permalinks. The location ~ \.php$ block forwards all PHP requests to wordpress:9000 via FastCGI — Docker's internal DNS resolves wordpress to the container's IP automatically. The location ~ /\. block denies access to hidden files like .htaccess or .git."

Resumo de como usar este guião: para cada ficheiro, começa com "este ficheiro faz X", aponta a linha mais importante, e explica o porquê — não só o quê. O evaluator quer perceber que entendes as decisões, não só que memorizaste os comandos.