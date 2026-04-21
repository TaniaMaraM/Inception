# Inception — Tania's Survival Guide

Yes, your husband helped. No, that doesn't matter — because by the time you're defending this,
you'll know every line of it better than he does. This document is your cheat sheet, your study
guide, and your pre-battle pep talk. Read it. Read it again. Then close it and explain it out loud
to the wall. The wall won't judge you. The evaluator might.

---

## Step 0: Setting up VirtualBox and deploying the project

Before any Docker magic, you need a Linux VM. Think of it as your project's home — a little
computer inside your computer, like a dream within a dream. Appropriate for a project called Inception.

### Install VirtualBox

1. Go to [virtualbox.org](https://www.virtualbox.org) and download the installer for your OS. Install it normally.
2. Also download and install the **VirtualBox Extension Pack** from the same page — same version as VirtualBox. It adds USB support and better display drivers. Don't skip it, it'll save you headaches later.

### Download a Debian ISO

Go to [debian.org/distrib](https://www.debian.org/distrib/) and download the latest **stable** netinstall ISO (the small one, ~400 MB). Debian bookworm (12) is what the project uses. Don't grab anything that says "testing" or "unstable" — those words mean what they say.

### Create the VM in VirtualBox

1. Open VirtualBox → click **New**
2. Fill in:
   - **Name**: Inception (or anything — this is your VM, name it after your cat if you want)
   - **Type**: Linux
   - **Version**: Debian (64-bit)
3. **Memory**: at least **2048 MB** (2 GB). Docker is hungry. Feed it.
4. **Hard disk**: create a new virtual disk, **20 GB** minimum, VDI format, dynamically allocated.
5. Click **Create**.

### Configure the VM before first boot

Right-click the VM → **Settings**:

- **System → Processor**: give it at least **2 CPUs**
- **Storage**: click the empty optical drive, click the disc icon on the right → "Choose a disk file" → select your Debian ISO
- **Network → Adapter 1**: set to **Bridged Adapter** (so the VM gets an IP on your local network and you can SSH into it from your Mac — no need to stare at a tiny VirtualBox window)

### Install Debian

1. Start the VM. It boots from the ISO.
2. Choose **Install** (text installer — easier than graphical, and you don't need a pretty UI to install an OS).
3. Language: English. Country: your country. Keyboard: your layout.
4. **Hostname**: `tmarcos` (your 42 login).
5. **Domain name**: leave blank. You don't need one.
6. **Root password**: set one you'll remember. Write it down. Seriously, write it down.
7. **Create a user**: username `tmarcos`, set a password.
8. **Partition**: use the entire disk, all files in one partition. Confirm and write to disk. Yes, it will erase the virtual disk. That's fine — it's a virtual disk.
9. **Software selection**: uncheck everything except **SSH server** and **standard system utilities**. No desktop environment — you won't need one, and it just wastes space.
10. **Install GRUB** to the primary drive: yes.
11. Finish and reboot. Congratulations, you have a Linux server.

When it asks to remove the installation medium, VirtualBox usually does this automatically. If the VM boots back into the installer, go to VM Settings → Storage and remove the ISO from the optical drive. Then reboot again.

### After Debian boots — first setup

Log in as `tmarcos` (your regular user, not root — root is for emergencies, not daily driving).

**Install sudo and add yourself to the sudo group:**
```bash
su -                          # switch to root
apt-get install -y sudo
usermod -aG sudo tmarcos
exit                          # back to tmarcos
```
Log out and back in for the group change to take effect. Yes, you have to log out. Linux is not macOS.

**Install Docker** (copy-paste this whole block — it's the official Docker install for Debian):
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

**Add yourself to the docker group** (so you don't need sudo for every single docker command):
```bash
sudo usermod -aG docker tmarcos
```
Log out and back in. Again. Last time, promise.

**Verify Docker works:**
```bash
docker run hello-world
```
You should see "Hello from Docker!". If you do, do a little dance. You earned it.

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

The `.env.example` already has all the values pre-filled. You only need to confirm `DATA_PATH=/home/tmarcos/data` matches your login. If your login is something other than `tmarcos`, open the file and fix it:
```bash
nano srcs/.env
```
Change every occurrence of `tmarcos` to your actual login. Save with `Ctrl+O`, exit with `Ctrl+X`. Welcome to nano.

### Register the domain

```bash
echo "127.0.0.1 tmarcos.42.fr" | sudo tee -a /etc/hosts
```

This tells the VM "when someone asks for `tmarcos.42.fr`, it's me." It's like adding yourself to your own contacts.

### Launch

```bash
make
```

First run takes a few minutes — it downloads packages and builds all three images. Go make a coffee. Come back. It'll be done.

```bash
# Test with curl inside the VM:
curl -k https://tmarcos.42.fr

# Or SSH port-forward from your Mac to see it in your Mac browser:
ssh -L 8443:localhost:443 tmarcos@<vm-ip>
# Then open https://localhost:8443 in Safari/Chrome
```

To find the VM's IP address: run `ip addr show` inside the VM and look for the IP on `enp0s3` (it'll look like `192.168.x.x`).

---

## The big picture

You built a mini web server. Someone types `https://tmarcos.42.fr` and sees a WordPress site.
Behind that URL, three programs are running — each minding its own business in its own container:

1. **NGINX** — the bouncer. Handles TLS (the padlock in the browser), then passes requests inside.
2. **WordPress (php-fpm)** — the kitchen. Takes the request, runs PHP, asks the database for data, serves the response.
3. **MariaDB** — the fridge. Stores posts, users, settings. Doesn't talk to the outside world — only WordPress knows it exists.

Each one runs in a **container**. Not a VM — a container. The difference matters, and the evaluator will ask.

---

## What is a container — for someone who knows C

You know `fork()`. When you fork, the child gets its own process but shares the parent's memory (copy-on-write). Now imagine Linux also letting you give the child its own isolated view of:
- the filesystem (`CLONE_NEWNS` — like `chroot` but you can't escape it)
- the network (`CLONE_NEWNET` — own interfaces, own routing table, no peeking at the host)
- the process IDs (`CLONE_NEWPID` — child sees itself as PID 1, thinks it owns the machine)

That's the syscall: `clone(CLONE_NEWPID | CLONE_NEWNS | CLONE_NEWNET)`. Docker calls it for you. A container is just a process with an identity crisis — it believes it's alone on a machine.

**A Docker image** is a frozen filesystem snapshot (read-only layers stacked via OverlayFS). Like a git repo: each layer is a commit, the running container is your working tree.

**A Dockerfile** is a recipe. `FROM debian:bookworm` is your base. Each `RUN` adds a layer. The final image is all layers merged into one read-only stack.

---

## Why three containers and not one

Because the project says so — but also because it makes sense. Each container does one thing. If WordPress crashes, MariaDB keeps running. If you update NGINX, you don't touch the database. It's the same reason you write separate C functions instead of putting everything in `main()` and hoping for the best.

**Say to the evaluator**: "Separation of concerns — each service is independently restartable, upgradeable, and replaceable."

---

## The network

All three containers are connected to a Docker bridge network called `inception`. Think of it as a private virtual Ethernet switch — only these three are plugged in, nobody else can hear them.

Docker runs an internal DNS resolver. Inside any container on this network, the hostname `mariadb` resolves to the MariaDB container's private IP. So WordPress connects to the database with `mariadb:3306` — no hardcoded IP addresses, no `/etc/hosts` hacks. NGINX sends PHP requests to `wordpress:9000` the same way.

From outside the network: you can only reach NGINX on port 443. MariaDB and WordPress are invisible to the outside world. As it should be.

**The evaluator will ask**: "How do containers find each other?"
**You say**: "Docker's internal DNS. Each service name in docker-compose.yml becomes a hostname that resolves inside the network."

---

## The volumes

If MariaDB kept its data inside the container, everything — every post, every user, every setting — would vanish when you run `make fclean`. That would be sad. Volumes fix this.

The `wp-db` volume is backed by a real directory on the host at `DATA_PATH/db`. When MariaDB writes to `/var/lib/mysql` inside the container, it's actually writing to that host directory. The container can die, be deleted, be rebuilt — the data survives on disk.

Same story for `wp-files`: WordPress core files and uploads live at `DATA_PATH/wordpress`, mounted at `/var/www/html` inside both WordPress and NGINX (NGINX needs the static files so it can serve images and CSS without bothering php-fpm for every request).

**The evaluator will ask**: "Show me that data persists after a reboot."
**You do**: create a post, `make down`, `sudo reboot`, `make`, open the site — your post is still there. Smile calmly. You knew it would be.

---

## Dockerfile walkthrough — line by line

### MariaDB

```dockerfile
FROM debian:bookworm
```
Base image. Must be debian or alpine, penultimate stable. `latest` is forbidden — "latest" is ambiguous and changes under you. Instant fail if you use it.

```dockerfile
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        mariadb-server \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mysql \
    && mkdir -p /var/lib/mysql /run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /run/mysqld
```
Install MariaDB. `DEBIAN_FRONTEND=noninteractive` stops apt from asking "what timezone are you in?" mid-build.
`rm -rf /var/lib/mysql` is the sneaky one — apt runs `mysql_install_db` during install, which seeds that directory inside the image layer. If we leave it there, Docker will copy it into the volume on first mount and our "has this been initialized?" check breaks silently. We wipe it here and initialize properly in the entrypoint.
`rm -rf /var/lib/apt/lists/*` — deletes the package index cache to shrink the image. Good hygiene.

```dockerfile
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/entrypoint.sh /tools/entrypoint.sh
RUN chmod +x /tools/entrypoint.sh
EXPOSE 3306
ENTRYPOINT ["/tools/entrypoint.sh"]
```
`EXPOSE 3306` is documentation only — it does not open any port to the outside. `ENTRYPOINT` in JSON array form (exec form) means no shell wrapper around it — the entrypoint script is launched directly and becomes PID 1.

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
php-fpm is the PHP process manager — it listens on port 9000 and runs PHP files on demand. `mariadb-client` is installed so the entrypoint can ping the database before starting. `wp-cli` is a command-line WordPress installer — it sets up the whole site without needing a browser. Neat.

### NGINX

```dockerfile
FROM debian:bookworm
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        nginx openssl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /etc/nginx/ssl \
    && rm -f /etc/nginx/sites-enabled/default
```
Install nginx and openssl (for the TLS certificate). Remove the default site that Debian's nginx package enables — it listens on port 80 and would conflict with our config. Gone.

---

## Entrypoint walkthrough — line by line

### Why `exec` at the end of every entrypoint

Every entrypoint ends with `exec mysqld`, `exec php-fpm8.2 -F -R`, or `exec nginx -g 'daemon off;'`.

In C terms: the shell script calls `execve()` on the daemon. The daemon **replaces** the shell process and inherits its PID — which is PID 1.

Why does this matter? `docker stop` sends `SIGTERM` to PID 1. If the shell is PID 1 and the daemon is a child, the shell gets `SIGTERM`, exits, and the daemon gets `SIGKILL` — no chance to flush data, no clean shutdown, nothing. With `exec`, the daemon IS PID 1 and handles `SIGTERM` like a grown-up.

**The evaluator will ask**: "Why do you use `exec` in your entrypoints?"
**You say**: "So the daemon becomes PID 1 and can handle SIGTERM gracefully when the container stops."
Then watch them nod approvingly.

### Why `tail -f` and `sleep infinity` are forbidden

These are lazy hacks to keep PID 1 alive. The real daemon becomes a child process, and if it crashes, the container doesn't notice — `tail -f` is still happily tailing nothing. `docker stop` sends SIGTERM to `tail`, not to the daemon. No clean shutdown. No crash detection. The evaluator will look for this. Don't give them the satisfaction.

### MariaDB entrypoint — the marker file pattern

```bash
MARKER=/var/lib/mysql/.initialized
if [ ! -f "$MARKER" ]; then
    # First run: initialize
    mysql_install_db ...
    mysqld --skip-networking &   # temporary instance, no outside connections
    # wait until it's ready
    # run SQL: CREATE DATABASE, CREATE USER, SET ROOT PASSWORD
    touch "$MARKER"
    kill $TEMP_PID
fi
exec mysqld --user=mysql        # the real instance, PID 1 from here
```

The marker file is a one-time flag — same pattern as creating a `.done` file in C after a first-run setup. We can't just check `[ ! -d /var/lib/mysql/mysql ]` because with a bind-mount volume, Docker doesn't pre-seed the directory from the image. Explicit marker, no surprises.

`--skip-networking` on the temporary instance: we don't want the temp mysqld to accept connections from other containers while we're initializing it. Only the entrypoint script talks to it via the unix socket.

### WordPress entrypoint — waiting for MariaDB

```bash
until mariadb -h mariadb -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" -e ";" 2>/dev/null; do
    echo "[wordpress] Waiting for MariaDB..."
    sleep 2
done
```

`depends_on: mariadb` in docker-compose.yml means "start mariadb's container before wordpress's container". It does NOT mean "wait until MariaDB is ready to accept connections" — Docker doesn't know or care what happens inside a container after it starts. MariaDB needs a few seconds to initialize. Without this loop, WordPress would crash on startup trying to connect to a database that isn't ready yet. Classic race condition. The loop is the fix.

It's exactly like polling a file descriptor in C: try, fail gracefully, wait, retry.

---

## The NGINX config

```nginx
listen 443 ssl;
```
Only port 443. There is no `listen 80`. The evaluator will try to open `http://tmarcos.42.fr` — it must fail completely. If it works, something is wrong.

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```
Only TLS 1.2 and 1.3. Older versions (1.0 and 1.1) are broken and disabled by omission. The evaluator may check this with `curl -v` or a browser's connection info.

```nginx
location ~ \.php$ {
    fastcgi_pass wordpress:9000;
    ...
}
```
Any `.php` request gets forwarded to the WordPress container via FastCGI. FastCGI is a binary protocol — NGINX encodes the request details (method, headers, script path) and sends them over TCP to php-fpm on port 9000. php-fpm decodes, runs the PHP file, returns the output. NGINX sends it back to the browser. Simple, elegant, separated.

---

## Questions the evaluator WILL ask — with answers

Memorise these. Say them out loud in the shower. Explain them to your plant.

**"Explain how Docker and docker-compose work."**
Docker uses Linux namespaces and cgroups to run isolated processes. An image is a layered, read-only filesystem snapshot. A container is a running instance with its own PID, network, and filesystem view. Docker Compose reads a YAML file and orchestrates multiple containers with the right networks, volumes, environment variables, and restart policies — instead of typing `docker run` with twenty flags for each service.

**"What is the difference between a Docker image used with and without docker-compose?"**
The image is identical either way. Compose just automates the `docker run` command: which network to join, which volumes to mount, which env file to inject, what restart policy to apply. Convenience wrapper, nothing more.

**"What is the benefit of Docker compared to VMs?"**
Containers share the host kernel — millisecond startup, minimal memory overhead. A VM emulates hardware and boots a full kernel — seconds to start, hundreds of MB just for the OS. The tradeoff: containers share the kernel, so they're less isolated than VMs. For this project, the tradeoff is fine — we control all three services.

**"Explain the directory structure of this project."**
`srcs/` has the Compose file, `.env`, and `requirements/` with one folder per service. Each service has a `Dockerfile`, `conf/` for config files, and `tools/` for the entrypoint. `secrets/` holds credential files (gitignored). The `Makefile` at the root orchestrates everything.

**"Explain docker-network."**
A Docker bridge network is a virtual Ethernet switch. Each container on it gets a private IP. Docker's internal DNS lets containers resolve each other by service name — no hardcoded IPs. Nothing outside can reach a container unless it's explicitly published with `ports:`.

**"How do you log into the MariaDB database?"**
```bash
docker exec -it mariadb mariadb -u wpuser -pwpuserpass123 wordpress
```
Say it confidently. Type it without hesitation. Run `SHOW TABLES;` inside and smile.

**"Why can't the admin username contain 'admin'?"**
Security. `admin` is the first username any attacker tries. The project enforces a non-obvious username. Ours is `taniawp`.

**"How does NGINX know where WordPress is?"**
Docker's internal DNS resolves the service name `wordpress` to the container's IP. `fastcgi_pass wordpress:9000` in the NGINX config uses that name — Docker handles the rest.

**"What happens if one container crashes?"**
`restart: unless-stopped` tells Docker to restart it automatically — like a watchdog process. Same reason systemd has service restart policies.

**"Why do you use `exec` in the entrypoints?"**
So the daemon becomes PID 1 and handles SIGTERM from `docker stop` gracefully. Without `exec`, the daemon is a child process and gets SIGKILL with no clean shutdown.

---

## The instant-0 list — tatoo this on your brain

If the evaluator finds any of these, it's over. None of them are in this project, but know why each one is forbidden:

- `tail -f` / `sleep infinity` — fake PID 1, no signal handling, no crash detection
- Passwords in any Dockerfile — credentials must come from the environment at runtime, never baked into an image
- `network: host` or `--link` — forbidden by the spec; breaks isolation and portability
- `image: wordpress` or any pre-built service image — you must write every Dockerfile yourself
- Base image tagged `latest` — non-deterministic, can change between builds
- No `networks:` section — containers must be on a named custom network
- Admin username containing "admin" or "Admin" — security requirement, instant fail

---

## Live demo checklist — the day of the evaluation

Run through this the night before. Then run through it again in the morning.

- [ ] `make` — all three containers start without errors
- [ ] `docker ps` — shows mariadb, wordpress, nginx all running
- [ ] Open `https://tmarcos.42.fr` — WordPress site loads (accept the cert warning)
- [ ] Open `https://tmarcos.42.fr/wp-admin` — log in as `taniawp` / `taniawppass123`
- [ ] `docker exec wordpress wp user list --allow-root` — shows `taniawp` and `taniareader`
- [ ] `docker exec -it mariadb mariadb -u wpuser -pwpuserpass123 wordpress` → `SHOW TABLES;` → `EXIT`
- [ ] `curl http://tmarcos.42.fr` — connection refused (no port 80)
- [ ] Create a post, `make down`, `make all` — post is still there
- [ ] Full evaluator wipe, then `make` — everything comes back from scratch

---

You wrote every Dockerfile. You understand every entrypoint. You debugged the MariaDB init.
You set up a VM from scratch. You did the thing.

Now go get that grade. Your husband is rooting for you — and so is this document.
