*This project has been created as part of the 42 curriculum by tmarcos.*

# Inception

A small web infrastructure built with Docker Compose, running inside a virtual machine. Three containers communicate over a private network: NGINX terminates TLS and forwards requests, WordPress with php-fpm serves the application, and MariaDB stores the data. All traffic enters on port 443 only.

## Stack

| Container | Role | Exposed |
|-----------|------|---------|
| nginx | TLS termination, reverse proxy | 443 (host) |
| wordpress | php-fpm application server | internal only |
| mariadb | relational database | internal only |

## Usage

```bash
# Start everything (builds images on first run)
make

# Stop containers (data is preserved)
make down

# Stop + remove containers and volumes
make clean

# Full wipe including images and host data directories
make fclean

# Wipe and rebuild from scratch
make re
```

Access the site at `https://tmarcos.42.fr` (accept the self-signed certificate warning).
WordPress admin panel: `https://tmarcos.42.fr/wp-admin`

## Setup

1. Clone the repository inside the VM
2. Copy `srcs/.env.example` to `srcs/.env` and fill in all values
3. Add `127.0.0.1 tmarcos.42.fr` to `/etc/hosts`
4. Run `make`

All credentials live in `srcs/.env` (gitignored). Never commit that file.

---

## VM vs Docker

A **virtual machine** emulates a full computer: it has its own kernel, its own boot sequence, and its own isolated hardware. Starting a VM takes seconds to minutes and costs hundreds of megabytes of RAM just to run the OS.

A **Docker container** does not have its own kernel. It shares the host kernel but runs in an isolated view of the filesystem, processes, and network using Linux kernel features (`namespaces` and `cgroups`). Starting a container takes milliseconds. Ten containers on the same machine share one kernel.

The tradeoff: containers are less isolated than VMs. If the host kernel has a vulnerability, containers are potentially exposed. VMs provide stronger isolation because the hypervisor sits between the guest OS and the hardware.

In this project, Docker is appropriate because we control all three services and trust them. We get faster iteration and less overhead without needing the stronger boundary a VM would provide.

---

## Secrets vs Environment Variables

An **environment variable** is a key-value pair passed to a process at startup. In Docker Compose, `env_file: .env` injects variables into the container's environment. Any process inside can read them with `getenv("MYSQL_PASSWORD")`. They are convenient but visible to anyone who runs `docker inspect` on the container.

A **secret** is a value stored in a file (typically in a `secrets/` directory, gitignored) and mounted into the container at a controlled path. The process reads the file instead of the environment. This prevents the value from appearing in `docker inspect` output, process listings, or logs.

This project uses `.env` for all credentials. The `secrets/` directory exists as a gitignored holding area for the actual values. In a production environment you would use Docker Swarm secrets or a secrets manager (Vault, AWS Secrets Manager) so credentials never appear in environment variables at all.

---

## Docker Network vs Host Network

With **host networking** (`network: host`), a container shares the host's network stack directly. Port 80 in the container is port 80 on the host. There is no isolation. This is forbidden in this project and generally avoided because it breaks container portability and exposes all container ports to the outside.

With a **Docker bridge network** (what this project uses), Docker creates a virtual switch. Each container gets a private IP address on that switch. Containers on the same network can reach each other by service name — Docker's internal DNS resolves `mariadb` to the MariaDB container's IP automatically. Nothing on the bridge network is reachable from outside unless explicitly published with `ports:`.

In this project, the `inception` bridge network allows WordPress to connect to MariaDB at `mariadb:3306` and NGINX to forward PHP requests to `wordpress:9000`, while only port 443 is published to the host.

---

## Docker Volumes vs Bind Mounts

A **bind mount** links a specific path on the host directly into the container. The host path must exist before the container starts. It is tightly coupled to the host's directory structure.

A **Docker named volume** is managed by Docker: Docker owns the lifecycle, handles creation, and abstracts the storage location. By default Docker stores volume data under `/var/lib/docker/volumes/`. However, named volumes can be configured with `driver: local` and `type: none, o: bind` to back them with a specific host directory — combining the management benefits of named volumes with explicit placement of data.

This project uses named volumes (`wp-db`, `wp-files`) backed by host directories at `DATA_PATH/db` and `DATA_PATH/wordpress`. This means:
- Docker tracks the volumes and can list/inspect them with `docker volume ls`
- Data survives container restarts and rebuilds
- Data survives `make down` and `make clean`
- Data is only deleted by `make fclean`, which explicitly removes the host directories
