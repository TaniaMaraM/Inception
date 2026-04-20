# Docker Secrets

## What it is

Docker Secrets is a Docker mechanism to inject sensitive values into containers **as files**, instead of environment variables. The value is mounted at `/run/secrets/<name>` inside the container, and the process reads the file directly.

```bash
# Instead of reading from an environment variable:
os.getenv("MYSQL_PASSWORD")   # visible in docker inspect

# The process reads a file:
cat /run/secrets/mysql_password   # not visible in docker inspect
```

---

## Why it matters

### The problem with `.env` and environment variables

Environment variables are convenient but have a security flaw: they are visible to anyone with access to the Docker daemon.

```bash
docker inspect wordpress
```

Output includes:

```json
"Env": [
    "MYSQL_PASSWORD=mysecretpassword",
    "WP_ADMIN_PASSWORD=anotherone",
    ...
]
```

Any user who can run `docker inspect` — or read `/proc/<pid>/environ` inside the container — can see every credential passed via environment variables.

### How Docker Secrets compares

| | `.env` / environment variables | Docker Secrets |
|---|---|---|
| Stored in container environment | **Yes** | No |
| Visible in `docker inspect` | **Yes** | No |
| Visible in `ps aux` / `/proc/*/environ` | **Yes** | No |
| Mounted as a file in the container | No | Yes — at `/run/secrets/<name>` |
| Protected in Docker Swarm | No | Yes — encrypted in transit and at rest |
| Requires Swarm mode | No | Swarm: yes. Compose: no (uses local files) |

### What the 42 subject says

> *"It is strongly recommended that you use Docker secrets to store any confidential information. Any credentials, API keys, or passwords found in your Git repository (outside of properly configured secrets) will result in project failure."*

Using Docker Secrets is **strongly recommended, not mandatory**. However, if an evaluator runs `docker inspect` during evaluation and sees passwords in plain text in the `Env` block, they may question the implementation.

---

## Step-by-step implementation

### Step 1 — Create the secrets directory and files

Each secret is a plain text file containing **only the value** (no `KEY=value` format).

```bash
mkdir -p secrets
echo "a_strong_db_password"    > secrets/db_password.txt
echo "a_strong_root_password"  > secrets/db_root_password.txt
echo "a_strong_admin_password" > secrets/wp_admin_password.txt
echo "a_strong_user_password"  > secrets/wp_user_password.txt
```

Make sure these files are in `.gitignore`:

```gitignore
secrets/
```

> Never commit the contents of `secrets/`. Create them locally on the VM only.

---

### Step 2 — Declare secrets in `docker-compose.yml`

Add a top-level `secrets:` block and reference each secret file:

```yaml
secrets:
  db_password:
    file: ../secrets/db_password.txt
  db_root_password:
    file: ../secrets/db_root_password.txt
  wp_admin_password:
    file: ../secrets/wp_admin_password.txt
  wp_user_password:
    file: ../secrets/wp_user_password.txt
```

Then attach the relevant secrets to each service:

```yaml
services:
  mariadb:
    build: requirements/mariadb
    image: mariadb
    restart: unless-stopped
    env_file: .env
    secrets:
      - db_password
      - db_root_password
    volumes:
      - wp-db:/var/lib/mysql
    networks:
      - inception

  wordpress:
    build: requirements/wordpress
    image: wordpress
    restart: unless-stopped
    env_file: .env
    secrets:
      - db_password
      - wp_admin_password
      - wp_user_password
    depends_on:
      - mariadb
    volumes:
      - wp-files:/var/www/html
    networks:
      - inception

  nginx:
    build: requirements/nginx
    image: nginx
    restart: unless-stopped
    env_file: .env
    ports:
      - "443:443"
    depends_on:
      - wordpress
    volumes:
      - wp-files:/var/www/html
    networks:
      - inception
```

When a secret is listed under a service, Docker mounts it as a read-only file at `/run/secrets/<secret_name>` inside that container.

---

### Step 3 — Remove passwords from `.env`

The `.env` file should no longer contain the actual secret values. Keep only non-sensitive variables:

```env
LOGIN=tmarcos
DOMAIN_NAME=tmarcos.42.fr
DATA_PATH=/home/tmarcos/data

MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser

WP_ADMIN_USER=tmarcos_admin
WP_ADMIN_EMAIL=admin@tmarcos.42.fr

WP_USER=tmarcos_user
WP_USER_EMAIL=user@tmarcos.42.fr
```

Passwords are no longer here — the entrypoints read them from `/run/secrets/`.

---

### Step 4 — Update the MariaDB entrypoint

Instead of reading `$MYSQL_PASSWORD` and `$MYSQL_ROOT_PASSWORD` from the environment, read them from the secret files:

```bash
#!/bin/bash
set -e

# Read secrets from files mounted by Docker
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

MARKER=/var/lib/mysql/.initialized

if [ ! -f "$MARKER" ]; then

    mysql_install_db --user=mysql --datadir=/var/lib/mysql --skip-test-db

    mysqld --user=mysql --skip-networking &
    TEMP_PID=$!

    until mysqladmin ping --silent 2>/dev/null; do
        sleep 1
    done

    cat > /tmp/init.sql << EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

    mysql --user=root < /tmp/init.sql
    rm /tmp/init.sql
    touch "$MARKER"

    kill $TEMP_PID
    wait $TEMP_PID 2>/dev/null || true

fi

exec mysqld --user=mysql
```

---

### Step 5 — Update the WordPress entrypoint

```bash
#!/bin/bash
set -e

# Read secrets from files mounted by Docker
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

WP_PATH=/var/www/html

RETRIES=30
until mariadb -h mariadb -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" -e ";" 2>/dev/null; do
    RETRIES=$((RETRIES - 1))
    [ $RETRIES -eq 0 ] && echo "[wordpress] MariaDB not ready. Aborting." && exit 1
    echo "[wordpress] Waiting for MariaDB..."
    sleep 2
done

if [ ! -f "${WP_PATH}/wp-config.php" ]; then

    wp core download --path="${WP_PATH}" --allow-root

    wp config create \
        --path="${WP_PATH}" \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost=mariadb \
        --allow-root

    wp core install \
        --path="${WP_PATH}" \
        --url="https://${DOMAIN_NAME}" \
        --title="Inception" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
        --path="${WP_PATH}" \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=subscriber \
        --allow-root

fi

exec php-fpm8.2 -F -R
```

---

### Step 6 — Verify the result

After `make`, confirm that passwords are no longer visible in the container environment:

```bash
# This should NOT show any password values
docker inspect wordpress | grep -A 30 '"Env"'

# Confirm the secret file exists inside the container
docker exec wordpress cat /run/secrets/db_password

# Confirm the environment variable for the password is gone
docker exec wordpress env | grep PASSWORD
```

---

## Final structure

```
Inception/
├── Makefile
├── secrets/                        ← gitignored, created locally on the VM
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env                        ← gitignored, no passwords
    ├── .env.example                ← committed, no passwords
    ├── docker-compose.yml          ← declares secrets block
    └── requirements/
        ├── mariadb/
        │   └── tools/entrypoint.sh ← reads from /run/secrets/
        └── wordpress/
            └── tools/entrypoint.sh ← reads from /run/secrets/
```

---

## Summary

| | Before (`.env` only) | After (Docker Secrets) |
|---|---|---|
| Passwords in `docker inspect` | **Yes** | No |
| Passwords in container env | **Yes** | No |
| Passwords in git | No (gitignored) | No (gitignored) |
| Subject compliance | Minimum | Recommended level |
| Evaluator `docker inspect` risk | Present | Eliminated |

---

## Em português — O que são e por que importam

### O que é um Docker Secret

Docker Secrets é um mecanismo do Docker para injectar valores sensíveis nos containers **como ficheiros**, em vez de variáveis de ambiente. O valor fica montado em `/run/secrets/<nome>` dentro do container, e o processo lê o ficheiro directamente.

### O problema das variáveis de ambiente

Variáveis de ambiente são convenientes, mas têm uma falha de segurança: qualquer pessoa com acesso ao Docker daemon consegue vê-las em plain text.

```bash
docker inspect wordpress
```

O output inclui algo assim:

```json
"Env": [
    "MYSQL_PASSWORD=mysecretpassword",
    "WP_ADMIN_PASSWORD=anotherone"
]
```

Se usares Docker Secrets, esse bloco `Env` não contém a password — ela está num ficheiro dentro do container, inacessível pelo `inspect`.

### A diferença prática

Com `.env`, o processo recebe a password assim:
```bash
echo $MYSQL_PASSWORD   # visível no ambiente do container
```

Com Docker Secrets, o processo lê de um ficheiro:
```bash
cat /run/secrets/db_password   # ficheiro montado pelo Docker, não aparece no inspect
```

### Por que é importante no 42

O subject diz que é *"strongly recommended"* — não é obrigatório. Mas se durante a avaliação o peer correr `docker inspect` e ver todas as passwords em plain text no output, pode questionar a implementação. Com secrets, esse risco desaparece.

### O fluxo resumido

1. Crias ficheiros de texto em `secrets/` (gitignored), cada um contendo apenas o valor da credencial.
2. Declaras esses ficheiros no `docker-compose.yml` sob um bloco `secrets:`.
3. Associas cada secret ao serviço que precisa dele.
4. Docker monta o ficheiro em `/run/secrets/<nome>` dentro do container.
5. O entrypoint lê o valor com `$(cat /run/secrets/<nome>)` em vez de `$VARIAVEL`.
6. As passwords deixam de aparecer em `docker inspect`, em `ps aux`, ou em `/proc/*/environ`.

O `.env` continua a existir e continua obrigatório — mas passa a conter apenas variáveis não sensíveis (nome do domínio, nome do utilizador, nome da base de dados). As passwords saem do `.env` e entram nos ficheiros de secret.
