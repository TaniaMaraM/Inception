# Inception — Everything Tania Needs to Know

This document is your personal guide for understanding and defending this project.
Read it, re-read it, and make sure you can explain every section out loud without looking at it.

---

## Step 0: Setting up VirtualBox and deploying the project

Before anything Docker-related, you need a Linux VM running on your computer. Here is the full process from zero.

### Install VirtualBox

1. Go to [virtualbox.org](https://www.virtualbox.org) and download the installer for your OS. Install it normally.
2. Also download and install the **VirtualBox Extension Pack** from the same page — same version as VirtualBox. It adds USB support and better display drivers.

### Download a Debian ISO

Go to [debian.org/distrib](https://www.debian.org/distrib/) and download the latest **stable** netinstall ISO (the small one, ~400 MB). Debian bookworm (12) is what the project uses.

### Create the VM in VirtualBox

1. Open VirtualBox → click **New**
2. Fill in:
   - **Name**: Inception (or anything)
   - **Type**: Linux
   - **Version**: Debian (64-bit)
3. **Memory**: at least **2048 MB** (2 GB). Docker needs memory.
4. **Hard disk**: create a new virtual disk, **20 GB** minimum, VDI format, dynamically allocated.
5. Click **Create**.

### Configure the VM before first boot

Right-click the VM → **Settings**:

- **System → Processor**: give it at least **2 CPUs**
- **Storage**: click the empty optical drive, click the disc icon on the right → "Choose a disk file" → select your Debian ISO
- **Network → Adapter 1**: set to **Bridged Adapter** (so the VM gets an IP on your local network and you can SSH into it from your Mac)

### Install Debian

1. Start the VM. It boots from the ISO.
2. Choose **Install** (text installer — easier than graphical).
3. Language: English. Country: your country. Keyboard: your layout.
4. **Hostname**: `tmarcos` (your 42 login).
5. **Domain name**: leave blank.
6. **Root password**: set one you'll remember. Write it down.
7. **Create a user**: username `tmarcos`, set a password.
8. **Partition**: use the entire disk, all files in one partition. Confirm and write to disk.
9. **Software selection**: uncheck everything except **SSH server** and **standard system utilities**. No desktop environment — you won't need one.
10. **Install GRUB** to the primary drive: yes.
11. Finish and reboot.

When it asks to remove the installation medium, VirtualBox usually does this automatically. If the VM boots back into the installer, go to VM Settings → Storage and remove the ISO from the optical drive.

### After Debian boots — first setup

Log in as `tmarcos` (your regular user, not root).

**Install sudo and add yourself to the sudo group:**
```bash
su -                          # switch to root
apt-get install -y sudo
usermod -aG sudo tmarcos
exit                          # back to tmarcos
```
Log out and back in for the group change to take effect.

**Install Docker:**
```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

**Add yourself to the docker group** (so you don't need sudo for every docker command):
```bash
sudo usermod -aG docker tmarcos
```
Log out and back in again.

**Verify Docker works:**
```bash
docker run hello-world
```
You should see "Hello from Docker!".

**Install make and git:**
```bash
sudo apt-get install -y make git
```

### Clone the project

```bash
cd ~
git clone https://github.com/TaniaMaraM/Inception.git
cd Inception
```

### Set up the environment file

```bash
cp srcs/.env.example srcs/.env
```

The `.env.example` already has all the values pre-filled for you. You only need to confirm `DATA_PATH=/home/tmarcos/data` matches your login.

If your login is different from `tmarcos`, edit the file:
```bash
nano srcs/.env
```
Change every occurrence of `tmarcos` to your actual login.

### Register the domain

```bash
echo "127.0.0.1 tmarcos.42.fr" | sudo tee -a /etc/hosts
```

### Launch

```bash
make
```

The first run takes a few minutes — it downloads packages and builds all three images. After that:

```bash
# Open the browser on the VM (if you have a GUI) or use curl:
curl -k https://tmarcos.42.fr

# Or SSH port-forward from your Mac to access it in your Mac browser:
# On your Mac terminal:
ssh -L 8443:localhost:443 tmarcos@<vm-ip>
# Then open https://localhost:8443 in your Mac browser
```

To find the VM's IP: run `ip addr show` inside the VM and look for the IP on the bridged interface (usually `enp0s3`).

---

## The big picture

You built a small web server. Someone types `https://tmarcos.42.fr` in a browser, and they see a WordPress site.

Behind that URL there are three programs running, each in its own isolated environment:

1. **NGINX** — the front door. Handles TLS (the S in HTTPS), then forwards the request inward.
2. **WordPress (php-fpm)** — the application. Receives the forwarded request, runs PHP, talks to the database, builds the HTML response.
3. **MariaDB** — the database. Stores posts, users, settings. Just data, nothing else.

Each program runs in a **container**. A container is not a virtual machine. It is a process on the Linux kernel with its own isolated view of the filesystem, the network, and the process list. Think of it like `chroot` on steroids.

---

## What is a container — for someone who knows C

When you write a C program and call `fork()`, you get a child process. That child shares the parent's memory until one of them writes (copy-on-write). Now imagine Linux also lets you give the child its own view of:
- the filesystem (`CLONE_NEWNS` — like `chroot` but stronger)
- the network (`CLONE_NEWNET` — own interfaces, own routing table)
- the process IDs (`CLONE_NEWPID` — child sees itself as PID 1)

That's what `clone(CLONE_NEWPID | CLONE_NEWNS | CLONE_NEWNET)` does. Docker calls it for you. The container IS a process — it just thinks it is running alone on its own machine.

**A Docker image** is a frozen filesystem snapshot (read-only layers). When you start a container, Docker adds a writable layer on top (OverlayFS). Like a git repository: base layers are commits, the running container is your working tree.

**A Dockerfile** is a recipe. Each `RUN` instruction adds a layer. `FROM debian:bookworm` is your base commit. `RUN apt-get install nginx` adds a layer with nginx installed. The final image is all those layers stacked.

---

## Why three containers and not one

The project rules say so, but there is also a real reason: each container does one thing. If WordPress crashes, MariaDB keeps running. If you need to update NGINX, you do not touch the database. This is the same reason you write separate C functions instead of one giant `main()`.

Also: the evaluator will ask you this. Say: "separation of concerns — each service is independently restartable, upgradeable, and replaceable."

---

## The network

All three containers are on a Docker bridge network called `inception`. Think of it as a virtual Ethernet switch that only these containers are plugged into.

Docker runs an internal DNS server. Inside any container on this network, the hostname `mariadb` resolves to the MariaDB container's IP. So WordPress connects to the database with host `mariadb`, not `127.0.0.1`. NGINX forwards PHP requests to `wordpress:9000` — Docker DNS resolves it.

Nothing outside can reach `mariadb` or `wordpress` directly. Only NGINX has a door to the outside, on port 443.

**The evaluator will ask**: "How do containers find each other?"
**Say**: "Docker's internal DNS. Each service name in docker-compose.yml becomes a resolvable hostname inside the network."

---

## The volumes

Data needs to survive container restarts. If MariaDB stored everything inside the container's writable layer, all posts and users would disappear when you run `make fclean`.

Named volumes solve this. The `wp-db` volume is backed by a real directory on the host at `DATA_PATH/db`. When MariaDB writes to `/var/lib/mysql` inside the container, it is actually writing to that host directory. The container can die and come back — the data is on the host disk.

Same for `wp-files`: WordPress files and uploads live at `DATA_PATH/wordpress` on the host, mounted at `/var/www/html` inside both the WordPress and NGINX containers (NGINX needs them to serve static files directly without going through php-fpm).

**The evaluator will ask**: "Show me that data persists after a reboot."
**Do**: `make down`, `sudo reboot`, `make`, open the site — everything is still there.

---

## Dockerfile walkthrough — line by line

### MariaDB

```dockerfile
FROM debian:bookworm
```
Base image. Must be debian or alpine, penultimate stable. Never `latest`.

```dockerfile
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        mariadb-server \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mysql \
    && mkdir -p /var/lib/mysql /run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /run/mysqld
```
Install MariaDB. `DEBIAN_FRONTEND=noninteractive` prevents apt from asking questions.
`rm -rf /var/lib/mysql` — critical: apt runs `mysql_install_db` during install, which seeds `/var/lib/mysql` with initial data. If we leave that in the image, Docker copies it into the volume on first mount and our "first run" detection breaks. We wipe it here and initialize properly in the entrypoint.
`rm -rf /var/lib/apt/lists/*` — shrinks the image by removing the package index cache.

```dockerfile
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /tools/entrypoint.sh
RUN chmod +x /tools/entrypoint.sh
EXPOSE 3306
ENTRYPOINT ["/tools/entrypoint.sh"]
```
Copy config and entrypoint. `EXPOSE` is documentation — it does not actually publish the port. `ENTRYPOINT` in JSON array form (exec form) means no shell wrapping — the entrypoint is PID 1 directly.

### WordPress

```dockerfile
FROM debian:bookworm
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        php8.2-fpm php8.2-mysql php8.2-curl php8.2-gd php8.2-mbstring \
        php8.2-xml php8.2-zip curl mariadb-client \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/php /var/www/html \
    && curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp
```
Install php-fpm and the PHP extensions WordPress needs. `mariadb-client` is installed so the entrypoint can use `mariadb -h mariadb` to wait for the database to be ready. `wp-cli` is a command-line tool that can install and configure WordPress without a browser — we use it in the entrypoint.

### NGINX

```dockerfile
FROM debian:bookworm
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        nginx openssl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /etc/nginx/ssl \
    && rm -f /etc/nginx/sites-enabled/default
```
Install nginx and openssl (for generating the TLS certificate). Remove the default site that comes with the debian nginx package — it would conflict with our config.

---

## Entrypoint walkthrough — line by line

### Why `exec` at the end of every entrypoint

Every entrypoint ends with `exec mysqld`, `exec php-fpm8.2 -F -R`, or `exec nginx -g 'daemon off;'`.

In C terms: the shell script calls `execve()` on the daemon. The daemon **replaces** the shell process. It inherits the same PID — PID 1.

Why does this matter? When you run `docker stop`, Docker sends `SIGTERM` to PID 1. If PID 1 is the shell and the daemon is a child process, the shell receives `SIGTERM`, exits, and the daemon gets `SIGKILL` with no chance to flush writes to disk. With `exec`, the daemon IS PID 1 and handles `SIGTERM` gracefully.

**The evaluator will ask**: "Why do you use `exec` in your entrypoints?"
**Say**: "So the daemon becomes PID 1 and can handle SIGTERM gracefully when the container stops."

### Why `tail -f` and `sleep infinity` are forbidden

These keep PID 1 alive artificially. The real daemon runs as a child process, and your entrypoint has no way to pass signals to it or know if it crashed. If mysqld dies, the container keeps running because `tail -f` is still alive. The evaluator's `docker stop` sends SIGTERM to `tail`, not to mysqld. No clean shutdown, no crash detection. Instant fail.

### MariaDB entrypoint — the marker file pattern

```bash
MARKER=/var/lib/mysql/.initialized
if [ ! -f "$MARKER" ]; then
    # First run: initialize
    mysql_install_db ...
    mysqld --skip-networking &   # temporary instance, no external connections
    # wait for it to be ready
    # run SQL: CREATE DATABASE, CREATE USER, SET ROOT PASSWORD
    touch "$MARKER"
    kill $TEMP_PID
fi
exec mysqld --user=mysql        # real instance, PID 1
```

Why the marker file? We can't use `[ ! -d /var/lib/mysql/mysql ]` because the volume is a bind mount — if the host directory is empty, Docker might not seed it from the image. The marker file is explicit: if it exists, we already ran initialization.

Why `--skip-networking` for the temporary instance? We don't want the temp mysqld to accept connections from the network while it's being initialized. Only the entrypoint script talks to it via the unix socket.

### WordPress entrypoint — waiting for MariaDB

```bash
until mariadb -h mariadb -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" -e ";" 2>/dev/null; do
    echo "[wordpress] Waiting for MariaDB..."
    sleep 2
done
```

`depends_on: mariadb` in docker-compose.yml only means "start mariadb before wordpress". It does NOT mean "wait until mariadb is ready to accept connections". MariaDB takes a few seconds to initialize. Without this loop, WordPress would try to connect immediately and fail.

This is a polling loop — exactly like polling a file descriptor in C: try, sleep, retry.

---

## The NGINX config

```nginx
listen 443 ssl;
```
Only port 443. There is no `listen 80`. Port 80 cannot be reached. The evaluator will try — it must fail.

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```
Only TLS 1.2 and 1.3. TLS 1.0 and 1.1 are disabled by not listing them.

```nginx
location ~ \.php$ {
    fastcgi_pass wordpress:9000;
    ...
}
```
Any request for a `.php` file is forwarded to the WordPress container on port 9000 via FastCGI. FastCGI is like a socket protocol: NGINX encodes the request (method, headers, path) into a binary format and sends it over TCP to php-fpm. php-fpm decodes it, runs the PHP file, and sends the response back.

---

## Questions the evaluator WILL ask — with answers

**"Explain how Docker and docker-compose work."**
Docker uses Linux namespaces and cgroups to run isolated processes. An image is a layered filesystem snapshot. A container is a running instance with its own PID, network, and filesystem namespace. Docker Compose reads a YAML file and runs multiple containers with the right networks, volumes, and environment variables — instead of running `docker run` with a dozen flags for each container.

**"What is the difference between a Docker image used with and without docker-compose?"**
The image is the same either way. Docker Compose just automates the `docker run` command with the correct arguments: which network to join, which volumes to mount, which env file to load, what restart policy to apply.

**"What is the benefit of Docker compared to VMs?"**
Containers share the host kernel — they start in milliseconds and use almost no extra memory for the OS. A VM boots a full kernel and emulates hardware, which costs seconds and hundreds of megabytes. The tradeoff is that containers share the kernel, so they are less isolated than VMs.

**"Explain the directory structure of this project."**
`srcs/` contains the Compose file, the `.env`, and `requirements/` with one subdirectory per service. Each service has a `Dockerfile`, a `conf/` for configuration files, and `tools/` for the entrypoint script. `secrets/` holds plaintext credential files (gitignored). The `Makefile` at the root orchestrates building and running everything.

**"Explain docker-network."**
A Docker bridge network is like a virtual Ethernet switch. Containers connected to it get private IP addresses and can reach each other. Docker runs an internal DNS server so containers can resolve each other by service name. Nothing outside the network can reach them unless a port is published with `ports:`.

**"How do you log into the MariaDB database?"**
```bash
docker exec -it mariadb mariadb -u wpuser -pwpuserpass123 wordpress
```
The evaluator may ask you to do this live and run `SHOW TABLES;` inside.

**"Why can't the admin username contain 'admin'?"**
It's a security rule in the evaluation sheet. Using `admin` as a username is the first thing an attacker tries. The project requires a non-obvious username.

**"How does NGINX know where WordPress is?"**
Docker's internal DNS. In the NGINX config, `fastcgi_pass wordpress:9000` uses the service name `wordpress`. Docker resolves `wordpress` to the container's private IP on the `inception` network.

**"What happens if one container crashes?"**
`restart: unless-stopped` in docker-compose.yml tells Docker to restart it automatically. This is like a supervisor process — same reason systemd restarts services.

**"Why do you use `exec` in the entrypoints?"**
So the daemon becomes PID 1. Docker sends SIGTERM to PID 1 when stopping. If a shell is PID 1 and the daemon is a child, the daemon gets SIGKILL with no clean shutdown. With `exec`, the daemon handles SIGTERM itself.

---

## Things that cause an instant 0 — make sure none of these are in the code

- `tail -f`, `sleep infinity`, or any hack to keep a container alive artificially
- Passwords or credentials inside any Dockerfile
- `network: host` or `--link` anywhere
- Using `latest` as a base image tag
- No `networks:` section in docker-compose.yml
- Admin username containing "admin" or "Admin"
- Using a pre-built image (e.g., `image: wordpress`) instead of a Dockerfile you wrote

---

## Live demo checklist for the evaluation day

- [ ] `make` — all three containers start
- [ ] `docker ps` — shows all three running
- [ ] Open `https://tmarcos.42.fr` — WordPress site loads
- [ ] Open `https://tmarcos.42.fr/wp-admin` — log in as `taniawp`
- [ ] `docker exec wordpress wp user list --allow-root` — shows taniawp and taniareader
- [ ] `docker exec -it mariadb mariadb -u wpuser -pwpuserpass123 wordpress` then `SHOW TABLES;`
- [ ] `http://tmarcos.42.fr` — connection refused
- [ ] Create a post, run `make down`, run `make all`, post is still there
- [ ] Run the evaluator's full wipe command, then `make` — everything comes back

You built this. You understand every line. You've got this.
