# Inception — Guia de Preparação para Avaliação
**PT-BR com terminologia técnica em inglês | Login: tmarcos | Domain: tmarcos.42.fr**

---

## Índice

1. [Conceitos Fundamentais](#1-conceitos-fundamentais)
2. [Walk-through dos Ficheiros](#2-walk-through-dos-ficheiros)
3. [Perguntas que vão fazer — com respostas](#3-perguntas-que-vão-fazer--com-respostas)
4. [Key Points do Projecto](#4-key-points-do-projecto)
5. [O que o evaluator vai tentar para te ferrar](#5-o-que-o-evaluator-vai-tentar-para-te-ferrar)
6. [Comandos de demonstração](#6-comandos-de-demonstração)

---

## 1. Conceitos Fundamentais

### O que é Docker?

Docker é uma plataforma de containerização. Usa features do kernel Linux — especificamente **namespaces** e **cgroups** — para correr processos isolados. Cada container tem o seu próprio namespace de PID, de rede, e de filesystem, por isso acha que está sozinho na máquina. **Não é uma VM** — partilha o kernel do host, o que o torna muito mais leve.

**Analogia simples:** Um container usa um pedaço do teu computador com configuração limitada. Uma VM sobe um sistema operativo inteiro por cima do teu, o que dá sobrecarga. Container = quarto num hostel (partilhas as canalizações). VM = apartamento próprio (tens tudo separado, mas é muito mais caro).

---

### Docker Image vs Container

| | Image | Container |
|---|---|---|
| O que é | Snapshot somente-leitura do filesystem | Instância viva da image |
| Estado | Estático, congelado | Em execução, tem processos |
| Analogia | Receita de bolo | O bolo que saiu da receita |
| Layers | Empilhadas, imutáveis | Adiciona uma layer de escrita por cima |

**Como dizer em inglês:**
> "An image is a read-only layered filesystem snapshot — like a recipe. A container is a running instance of that image — like the dish you cooked. The image is static; the container is live. You can run many containers from the same image."

---

### Docker vs Docker Compose

| | Docker | Docker Compose |
|---|---|---|
| O que é | Motor que cria e corre containers | Orquestrador de múltiplos containers |
| Scope | Um container de cada vez | Sistema inteiro |
| Comando | `docker build`, `docker run` | `docker compose up` |
| Ficheiro | `Dockerfile` | `docker-compose.yml` |

A **image é exactamente a mesma** com ou sem Compose. O Compose apenas automatiza os argumentos do `docker run` — é um wrapper de conveniência.

**Como dizer em inglês:**
> "Docker builds and runs individual containers. Compose is an orchestration tool — it reads a YAML file and manages multiple containers as a system, handling networks, volumes, environment variables, and startup order. The image is identical either way."

---

### Docker vs VMs

| | Container | VM |
|---|---|---|
| Kernel | Partilha o do host | Tem o seu próprio |
| Boot | Milissegundos | Segundos a minutos |
| RAM | ~MB de overhead | ~GB só para o SO convidado |
| Isolamento | Namespaces Linux | Hardware virtualizado |

**Como dizer em inglês:**
> "Containers share the host kernel — millisecond startup, minimal memory overhead. VMs boot a full guest OS on top of virtualised hardware — seconds to start, gigabytes of RAM just for the OS. The tradeoff is isolation: VMs are stronger, but containers are sufficient when you control all the services."

---

### Como os containers comunicam entre si

Docker cria um **bridge network** — um switch Ethernet virtual privado. Cada container na rede recebe um IP privado. O Docker corre um **DNS interno** que resolve o nome do serviço para o IP do container.

- WordPress encontra MariaDB através de `mariadb:3306`
- NGINX encontra WordPress através de `wordpress:9000`
- Nenhum IP hardcoded. Nenhum `/etc/hosts` manual.

**Como dizer em inglês:**
> "Docker's internal DNS. Each service name in docker-compose.yml becomes a hostname that resolves inside the network automatically."

---

### Como funciona a persistência de dados

Por defeito, dados dentro de um container são efémeros — desaparecem quando o container é removido. **Volumes** resolvem isso fazendo bind-mount de uma directoria do host para dentro do container.

```
Container MariaDB                     Host (VM)
/var/lib/mysql  ←── bind-mount ───→  /home/tmarcos/data/db

Container WordPress + NGINX           Host (VM)
/var/www/html   ←── bind-mount ───→  /home/tmarcos/data/wordpress
```

O container pode morrer, ser apagado, reconstruído — os dados sobrevivem em disco.

**Como dizer em inglês:**
> "Volumes bind-mount a host directory into the container. When MariaDB writes to `/var/lib/mysql`, it's actually writing to `/home/tmarcos/data/db` on the host. The container can be destroyed and rebuilt, and the data survives on disk."

---

## 2. Walk-through dos Ficheiros

### `Makefile`

**PT-BR:**
> "O Makefile é a entrada do projecto. `make` cria as directorias de dados no host e depois chama o Docker Compose para construir as images e subir os containers em background. O `-include srcs/.env` importa as variáveis do `.env` para o Make. `make fclean` faz o wipe completo — images, volumes, redes e dados em disco. `make eval` é o reset pré-avaliação."

**EN:**
> "The Makefile is the project's entry point. `make` creates the host data directories then calls Docker Compose to build all images and start containers in detached mode. `-include srcs/.env` imports environment variables into Make. `make fclean` is the full wipe. `make eval` is the pre-evaluation clean state."

---

### `.env.example`

**PT-BR:**
> "É o template das credenciais. O `.env` real nunca é commitado — está no `.gitignore`. O evaluator vai ver-me criar o ficheiro com `cp srcs/.env.example srcs/.env`, o que prova que as credenciais não estão no código. Todas as variáveis são injectadas pelo Compose nos containers em runtime, nunca hardcoded."

**EN:**
> "This is the credentials template. The actual `.env` is never committed — it's gitignored. The evaluator watches me create it with `cp srcs/.env.example srcs/.env`, proving credentials aren't in the codebase. All variables are injected by Docker Compose at runtime."

---

### `docker-compose.yml`

**PT-BR:**
> "Orquestra os três serviços. Cada `build:` aponta para o Dockerfile respectivo — todas as images são construídas por nós. `restart: unless-stopped` reinicia containers que caem automaticamente. `env_file: .env` injeta credenciais. `depends_on` define a ordem de arranque. Os volumes são bind-mounts para `/home/tmarcos/data/` no host. Todos os containers estão na rede `inception` bridge onde o DNS interno do Docker resolve os nomes dos serviços."

**EN:**
> "Orchestrates the three services. Each `build:` points to its Dockerfile — all images are built by us, none pre-built. `restart: unless-stopped` auto-restarts crashed containers. `depends_on` sets startup order. Volumes are bind-mounts to `/home/tmarcos/data/` on the host. All containers share the `inception` bridge network where Docker's internal DNS resolves service names."

---

### MariaDB — `50-server.cnf`

**PT-BR:**
> "Configuração do servidor MariaDB. Corre como utilizador `mysql`, não root — least privilege. `bind-address 0.0.0.0` permite ligações de outros containers na rede Docker. O `datadir` aponta para `/var/lib/mysql`, que é exactamente onde o volume está montado. O socket Unix permite comunicação local durante a inicialização sem usar TCP."

**EN:**
> "MariaDB server config. Runs as user `mysql`, not root — least privilege. `bind-address 0.0.0.0` allows connections from other containers on the Docker network. `datadir` points to `/var/lib/mysql` — exactly where the volume is mounted. The Unix socket allows local communication during initialisation without TCP."

---

### MariaDB — `Dockerfile`

**PT-BR:**
> "Parte de `debian:bookworm`. Num único `RUN` instalo o MariaDB, limpo o cache do apt, e — linha crítica — apago `/var/lib/mysql`. O apt semeia essa directoria durante a instalação, mas com bind-mount volumes o Docker usa o que está no host. Se não apagasse, a detecção de first-run do entrypoint falhava silenciosamente. Recrio as directorias limpas e dou ownership ao utilizador `mysql`. `ENTRYPOINT` em exec form, sem shell intermediário."

**EN:**
> "Starts from `debian:bookworm`. In one `RUN` I install MariaDB, clean the apt cache, and — critical line — delete `/var/lib/mysql`. apt seeds that directory during install, but with bind-mount volumes Docker uses the host directory. Without this deletion, the first-run detection in the entrypoint would silently break. I recreate the directories clean and set ownership to user `mysql`. `ENTRYPOINT` in exec form, no shell wrapper."

---

### MariaDB — `entrypoint.sh`

**PT-BR:**
> "Duas fases: first-run e every-run. O marker file `/var/lib/mysql/.initialized` é a flag — se não existe, é a primeira vez. Inicializo com `mysql_install_db`, subo uma instância temporária com `--skip-networking` para nenhum outro container se ligar durante a setup, espero com um polling loop, executo o SQL que cria a base de dados e o utilizador com as credenciais do `.env`, crio o marker e mato a instância temporária. Termino sempre com `exec mysqld` — o `exec` substitui o script shell pelo mysqld, que passa a ser PID 1 e recebe o SIGTERM do `docker stop` directamente para fazer shutdown limpo."

**EN:**
> "Two phases: first-run and every-run. The marker file `/var/lib/mysql/.initialized` is the flag — if absent, it's the first run. I initialise with `mysql_install_db`, start a temporary `--skip-networking` instance so no other container can connect during setup, poll until ready, run SQL that creates the database and user from environment variables, create the marker, kill the temp instance. Always ends with `exec mysqld` — exec replaces the shell with mysqld, which becomes PID 1 and handles SIGTERM from `docker stop` directly for a clean shutdown."

---

### WordPress — `www.conf`

**PT-BR:**
> "Configuração do php-fpm. A linha mais importante é `listen = 9000` em vez de um socket Unix. Por defeito o php-fpm ouve num socket Unix que só funciona dentro do mesmo container, mas o NGINX está noutro container e precisa de TCP. `clear_env = no` é essencial — sem isto o php-fpm apaga as variáveis de ambiente dos workers e o WordPress não consegue aceder às credenciais da base de dados."

**EN:**
> "php-fpm configuration. The critical line is `listen = 9000` instead of a Unix socket. By default php-fpm uses a Unix socket that only works within the same container, but NGINX is in a different container and needs TCP. `clear_env = no` is essential — without it php-fpm strips all environment variables from workers and WordPress can't access database credentials."

---

### WordPress — `Dockerfile`

**PT-BR:**
> "Instalo o php-fpm e as extensões necessárias ao WordPress: `php8.2-mysql` para a base de dados, `php8.2-gd` para imagens, entre outras. O `mariadb-client` não é para correr um servidor — é para o entrypoint fazer ping à base de dados antes de arrancar. O `wp-cli` é uma ferramenta de linha de comandos que instala o WordPress completo sem browser, permitindo automatizar tudo no entrypoint."

**EN:**
> "I install php-fpm and the WordPress-required PHP extensions: `php8.2-mysql` for the database, `php8.2-gd` for images, others as needed. `mariadb-client` isn't to run a server — it's so the entrypoint can ping the database before starting. `wp-cli` is a command-line WordPress installer that sets up the entire site without a browser, allowing full automation in the entrypoint."

---

### WordPress — `entrypoint.sh`

**PT-BR:**
> "Três fases. Primeiro, polling loop que tenta ligar ao MariaDB de dois em dois segundos — o `depends_on` garante que o container arrancou, não que o serviço dentro está pronto. Segundo, se `wp-config.php` não existe no volume, wp-cli faz download do WordPress, cria o config com as credenciais do `.env`, instala o site, e cria o utilizador subscriber. O admin username é `tmarcos_wp` — sem 'admin', requisito de segurança do projecto. Terceiro, `exec php-fpm8.2 -F -R`: `-F` mantém em foreground, `-R` permite correr como root, `exec` faz do php-fpm o PID 1."

**EN:**
> "Three phases. First, a polling loop connecting to MariaDB every two seconds — `depends_on` waits for the container to start, not for the service inside to be ready. Second, if `wp-config.php` doesn't exist on the volume, wp-cli downloads WordPress, creates the config from environment variables, installs the site, and creates the subscriber user. Admin username is `tmarcos_wp` — no 'admin' substring, security requirement and instant fail if violated. Third, `exec php-fpm8.2 -F -R`: `-F` keeps it in foreground, `-R` allows running as root, `exec` makes php-fpm PID 1."

---

### NGINX — `Dockerfile`

**PT-BR:**
> "Instalo nginx e openssl. O openssl é para gerar o certificado TLS no entrypoint. A linha crítica é `rm -f /etc/nginx/sites-enabled/default` — o Debian instala o nginx com um site default activo na porta 80 que conflituaria com a nossa configuração de apenas HTTPS."

**EN:**
> "I install nginx and openssl — openssl is for generating the TLS certificate in the entrypoint. The critical line is `rm -f /etc/nginx/sites-enabled/default` — Debian's nginx comes with a default site on port 80 that would conflict with our HTTPS-only config."

---

### NGINX — `entrypoint.sh`

**PT-BR:**
> "Se o certificado ainda não existe, gera um certificado auto-assinado com openssl — RSA 2048 bits, 365 dias, CN igual ao domínio vindo da variável de ambiente. Depois `exec nginx -g 'daemon off;'` — sem `daemon off` o nginx faz fork para background, o shell termina, o container fecha. Com `daemon off` o nginx fica em foreground e torna-se PID 1 via `exec`."

**EN:**
> "If the certificate doesn't exist, generate a self-signed certificate with openssl — RSA 2048, 365 days, CN from the domain environment variable. Then `exec nginx -g 'daemon off;'` — without `daemon off` nginx forks to background, the shell exits, the container stops. With `daemon off` nginx stays in foreground and becomes PID 1 via `exec`."

---

### NGINX — `default.conf`

**PT-BR:**
> "`listen 443 ssl` — só HTTPS, sem porta 80 em lado nenhum no projecto. `ssl_protocols TLSv1.2 TLSv1.3` — versões antigas desactivadas por omissão. `location /` usa `try_files` para pretty permalinks do WordPress. `location ~ \.php$` encaminha PHP para `wordpress:9000` via FastCGI — o Docker resolve o nome `wordpress` para o IP do container. `location ~ /\.` nega acesso a ficheiros ocultos."

**EN:**
> "`listen 443 ssl` — HTTPS only, no port 80 anywhere in the project. `ssl_protocols TLSv1.2 TLSv1.3` — older versions disabled by omission. `location /` uses `try_files` for WordPress pretty permalinks. `location ~ \.php$` forwards PHP requests to `wordpress:9000` via FastCGI — Docker's DNS resolves `wordpress` to the container IP. `location ~ /\.` denies access to hidden files."

---

## 3. Perguntas que vão fazer — com respostas

---

**"What is Docker and how does it work?"**
> "Docker is a containerisation platform that uses Linux namespaces and cgroups to run isolated processes. Each container has its own PID, network, and filesystem namespace — it believes it's alone on the machine. It's not a VM — it shares the host kernel, which makes it much lighter and faster to start."

---

**"What is the difference between a Docker image and a container?"**
> "An image is a read-only layered filesystem snapshot — static, like a recipe. A container is a running instance of that image — live, with processes. The image never changes; the container adds a writable layer on top. You can run many containers from the same image."

---

**"What is the difference between Docker and Docker Compose?"**
> "Docker builds and runs individual containers. Compose orchestrates multiple containers — it reads a YAML file and handles networks, volumes, environment variables, startup order, and restart policies, all in one command. The image is identical either way; Compose just automates the `docker run` flags."

---

**"What is the difference between Docker and VMs?"**
> "Containers use a slice of your machine — they share the host OS kernel. VMs boot a full operating system on top of virtualised hardware. So containers start in milliseconds and use minimal memory; VMs take seconds to boot and waste gigabytes just keeping the guest OS alive. The tradeoff is isolation: VMs are stronger, containers are sufficient when you control all services."

---

**"Why exec at the end of every entrypoint?"**
> "exec replaces the shell process with the daemon — mysqld, php-fpm, or nginx becomes PID 1. Docker sends SIGTERM to PID 1 on `docker stop`. Without exec, the shell is PID 1 and the daemon is a child — SIGTERM kills the shell, the daemon gets SIGKILL with no chance to flush data or close connections cleanly. With exec, the daemon handles SIGTERM directly and shuts down gracefully."

---

**"Why can't you use `tail -f` or `sleep infinity`?"**
> "Those are fake PID 1 hacks. The real daemon becomes a child process. If it crashes, the container doesn't notice — `tail -f` keeps running. `docker stop` sends SIGTERM to `tail`, not to the daemon. No clean shutdown, no crash detection. The daemon is completely invisible to Docker's process management."

---

**"How do containers find each other?"**
> "Docker's internal DNS. Each service name in docker-compose.yml — `mariadb`, `wordpress`, `nginx` — becomes a hostname that resolves inside the network automatically. No hardcoded IPs, no `/etc/hosts` hacks. WordPress connects to `mariadb:3306`, NGINX sends PHP requests to `wordpress:9000`."

---

**"What is a Docker network?"**
> "A virtual Ethernet switch. Each container on it gets a private IP. Docker runs an internal DNS resolver so containers find each other by service name. Nothing outside can reach a container unless it's explicitly published with `ports:`. In this project, only NGINX on port 443 is reachable from outside."

---

**"Why does the WordPress container also have `mariadb-client` installed?"**
> "Not to run a database — to be able to ping MariaDB before starting. The entrypoint polls `mariadb -h mariadb ...` in a loop until the connection succeeds. Without this, WordPress would crash trying to connect to a database that hasn't finished initialising yet."

---

**"What is `depends_on` and what doesn't it do?"**
> "`depends_on: mariadb` tells Compose to start the mariadb container before the wordpress container. It does NOT wait for the service inside to be ready — Docker doesn't know or care what happens inside a container after it starts. That's why the entrypoint has the polling loop — it actually waits until MariaDB accepts connections."

---

**"Why is `/var/lib/mysql` deleted in the MariaDB Dockerfile?"**
> "When `apt` installs `mariadb-server`, it runs `mysql_install_db` during installation which seeds `/var/lib/mysql` inside the image layer. But with a bind-mount volume, Docker uses the host directory and ignores the image content — the host directory starts empty. If I left the seeded data in the image, my first-run detection using the marker file would never work correctly."

---

**"Why use a marker file instead of checking if the database exists?"**
> "With bind-mount volumes, Docker doesn't pre-populate the host directory from the image — it stays empty on first run. So checking for `/var/lib/mysql/mysql` would always be false and the initialisation would run on every container start, overwriting data. The marker file is an explicit one-time flag that survives because it's on the volume."

---

**"Why is `clear_env = no` in www.conf?"**
> "By default, php-fpm strips all environment variables from its worker processes before starting them. Without `clear_env = no`, the PHP workers have no access to the database credentials injected by Docker Compose, and WordPress would fail to connect to MariaDB."

---

**"Why `listen = 9000` instead of a Unix socket in www.conf?"**
> "By default, php-fpm listens on a Unix socket — a file that only works for processes within the same container. NGINX is in a different container and needs to reach php-fpm over the Docker network via TCP. Port 9000 over TCP is the only way that works across container boundaries."

---

**"What is FastCGI?"**
> "FastCGI is a binary protocol for communication between a web server and a backend process. NGINX receives an HTTP request for a `.php` file, encodes the request details — method, headers, script path — and sends them over TCP to php-fpm on port 9000. php-fpm decodes the request, executes the PHP script, and returns the output. NGINX sends it back to the browser."

---

**"Why `daemon off` in the NGINX command?"**
> "By default, NGINX forks to the background after starting. If we run `exec nginx` without `daemon off`, nginx spawns a background process and exits — the shell process that was PID 1 is now gone, so the container stops immediately. `daemon off` keeps nginx in the foreground so it can be PID 1 and keep the container alive."

---

**"Why is the certificate self-signed?"**
> "We don't have a real public domain — `tmarcos.42.fr` only resolves inside the VM via `/etc/hosts`. A certificate from a Certificate Authority requires proof of domain ownership over the public internet. The self-signed certificate is sufficient to enable TLS encryption, which is what the project requires. The browser will show a warning, which is expected."

---

**"Show me data persists after a reboot."**

```bash
# Create a post in WordPress
# Then:
make down
sudo reboot
# After reboot:
cd ~/Inception && make
# Open https://tmarcos.42.fr — post is still there
```

> "Data persists because the volumes are bind-mounts to `/home/tmarcos/data/` on the host filesystem. The containers can be destroyed and rebuilt, but the data stays on disk. The Docker volume is just a pointer to that host directory."

---

**"How do you connect to the MariaDB database?"**

```bash
docker exec -it inception-mariadb-1 mariadb -u tmarcos -ptmarcos123 tmarcosdb
```

> "I use `docker exec` to run a command inside the running container. `-it` gives an interactive terminal. Once inside, I can run `SHOW TABLES;` to verify the WordPress tables exist, or `SELECT user_login FROM wp_users;` to check the users."

---

**"Why can't the admin username contain 'admin'?"**
> "Security. 'admin' is the first username any attacker or bot tries in a brute-force attack. The project enforces a non-obvious admin username as a baseline security requirement. Our admin username is `tmarcos_wp`."

---

## 4. Key Points do Projecto

### Os 3 princípios que justificam tudo

**1. Separation of concerns**
Cada container faz uma coisa só. NGINX só termina TLS e faz proxy. WordPress só processa PHP. MariaDB só guarda dados. Se o WordPress crashar, a base de dados continua a correr. Se actualizares o NGINX, não tocas na base de dados.

**2. Least privilege**
MariaDB corre como utilizador `mysql`, não root. Os containers não têm acesso ao sistema host além do volume montado. As credenciais vêm de variáveis de ambiente, nunca baked into the image.

**3. Stateless containers, stateful volumes**
Os containers são descartáveis — podem ser destruídos e reconstruídos sem perda de dados. O estado vive nos volumes no host. Esta é a filosofia Docker correcta.

---

### Fluxo de um pedido HTTP

```
Browser (HTTPS:443)
       │
       ▼
  [NGINX container]
  - Termina TLS (desencripta)
  - Serve ficheiros estáticos directamente do volume wp-files
  - Para .php → FastCGI → wordpress:9000
       │
       ▼
  [WordPress/php-fpm container]
  - Executa o PHP
  - Consulta a base de dados → mariadb:3306
       │
       ▼
  [MariaDB container]
  - Retorna os dados
  - Escreve em /var/lib/mysql (= volume no host)
```

---

### Por que é que o NGINX monta o volume `wp-files`?

O NGINX precisa dos ficheiros estáticos do WordPress — CSS, JavaScript, imagens — para os servir directamente sem passar pelo php-fpm. É muito mais rápido. Se um pedido é para `/wp-content/uploads/image.jpg`, o NGINX serve o ficheiro directamente. Só os ficheiros `.php` vão para o php-fpm.

---

### O padrão exec + PID 1

Todos os entrypoints terminam com `exec`:
- `exec mysqld --user=mysql`
- `exec php-fpm8.2 -F -R`
- `exec nginx -g 'daemon off;'`

**O que `exec` faz:** substitui o processo shell pelo daemon. O daemon herda o PID do shell — que é PID 1.

**Porquê PID 1 importa:** `docker stop` manda `SIGTERM` ao PID 1. Se o daemon for PID 1, recebe o sinal e faz shutdown limpo. Se for filho do shell, recebe `SIGKILL` brutal sem hipótese de limpar nada.

---

## 5. O que o evaluator vai tentar para te ferrar

### Armadilhas clássicas

**"Tenta aceder por HTTP"**
```bash
curl http://tmarcos.42.fr
# DEVE falhar — connection refused. Sem porta 80.
```
Se responder com redirect ou qualquer coisa, é falha.

---

**"Mostra-me que as passwords não estão no código"**
```bash
git log --all --oneline   # mostrar histórico
git show HEAD:srcs/.env   # deve dar erro fatal
grep -r "tmarcos123" srcs/requirements/  # não deve encontrar nada
```
As passwords só existem no `.env`, que está no `.gitignore`.

---

**"O que acontece se eu fizer `docker stop` e `docker start`?"**
```bash
docker stop inception-wordpress-1
docker start inception-wordpress-1
# Site continua a funcionar — dados no volume, não no container
```

---

**"Porque é que usas `FROM debian:bookworm` e não `FROM debian:latest`?"**
> "`latest` é não-determinístico — muda sem aviso quando uma nova versão sai. Com `latest`, a mesma Dockerfile pode produzir images diferentes em momentos diferentes. `bookworm` é uma versão específica que garante builds reproducíveis. O projecto também proíbe explicitamente `latest`."

---

**"Podes usar a image oficial do WordPress do Docker Hub?"**
> "Não. O projecto exige que eu escreva todos os Dockerfiles. Usar `image: wordpress` do Docker Hub é falha imediata — estaria a usar trabalho de outra pessoa. Construo tudo a partir de `debian:bookworm`."

---

**"O que é o `restart: unless-stopped`?"**
> "É a restart policy. Se um container crashar, o Docker reinicia-o automaticamente. `unless-stopped` significa 'reinicia sempre, excepto se eu o parei manualmente com `docker stop`'. É equivalente a ter um watchdog process — como o systemd com `Restart=on-failure`."

---

**"Mostra-me os volumes e onde os dados estão no disco"**
```bash
docker volume ls
docker volume inspect inception_wp-db
# Mostrar Mountpoint: /home/tmarcos/data/db
ls -la /home/tmarcos/data/db/
# Ver os ficheiros do MariaDB em disco
```

---

**"Verifica as versões do TLS"**
```bash
# TLS 1.2 — deve ACEITAR:
openssl s_client -connect tmarcos.42.fr:443 -tls1_2 < /dev/null

# TLS 1.3 — deve ACEITAR:
openssl s_client -connect tmarcos.42.fr:443 -tls1_3 < /dev/null

# TLS 1.1 — deve REJEITAR:
openssl s_client -connect tmarcos.42.fr:443 -tls1_1 < /dev/null
# Expected: "no protocols available" ou "ssl handshake failure"
```

---

**"Entra na base de dados e mostra-me os utilizadores do WordPress"**
```bash
docker exec -it inception-mariadb-1 mariadb -u tmarcos -ptmarcos123 tmarcosdb
# Dentro:
SHOW TABLES;
SELECT user_login, user_email, user_registered FROM wp_users;
EXIT
```

---

**"O que acontece se eu apagar um container e o recriar?"**
```bash
docker stop inception-mariadb-1
docker rm inception-mariadb-1
docker compose -f srcs/docker-compose.yml -p inception up -d mariadb
# MariaDB volta. O marker file existe. Não reinicializa. Dados intactos.
```

---

**"Porque é que o WordPress também tem o mariadb-client?"**
Armadilha — parece redundante ter o cliente de base de dados no container WordPress. A resposta:
> "Para o entrypoint poder verificar se o MariaDB está pronto antes de tentar ligar. É um health check manual com polling — sem ele, o WordPress crashava na startup porque tentava conectar a uma base de dados que ainda não terminou de inicializar."

---

**"Mostra-me que não há passwords no histórico do git"**
```bash
git log --all -p | grep -i "password"
# Não deve mostrar nenhuma password real — só referências a variáveis como ${MYSQL_PASSWORD}
```

---

### Instant fail — coisas que terminam a avaliação imediatamente

| Problema | Porquê é fatal |
|---|---|
| `FROM debian:latest` em qualquer Dockerfile | Non-determinístico, explicitamente proibido |
| `image: wordpress` ou qualquer image pré-feita | Tens que escrever os Dockerfiles tu próprio |
| `network: host` ou `--link` | Proibido pela especificação |
| `tail -f` ou `sleep infinity` no entrypoint | Fake PID 1, sem signal handling |
| Passwords hardcoded num Dockerfile | Credenciais devem vir do ambiente em runtime |
| Port 80 a responder | Só HTTPS, sem HTTP |
| Admin username com "admin" | Requisito de segurança |
| `.env` commitado no repositório | Expõe credenciais |
| Sem secção `networks:` no Compose | Containers devem estar numa rede nomeada |

---

## 6. Comandos de demonstração

### Sequência completa de avaliação

```bash
# 0. Reset — estado limpo
make eval

# 1. Criar .env (evaluator observa)
cp srcs/.env.example srcs/.env
cat srcs/.env

# 2. Confirmar que .env não está no git
git show HEAD:srcs/.env   # deve dar erro

# 3. Build e arranque
make

# 4. Verificar containers
docker compose -p inception ps

# 5. Verificar rede
docker network ls
docker network inspect inception_inception

# 6. Verificar volumes
docker volume ls
docker volume inspect inception_wp-db
docker volume inspect inception_wp-files

# 7. Testar HTTPS
curl -kI https://tmarcos.42.fr

# 8. Confirmar que HTTP não responde
curl http://tmarcos.42.fr

# 9. TLS versions
openssl s_client -connect tmarcos.42.fr:443 -tls1_2 < /dev/null 2>&1 | grep -E "Protocol|CONNECTED"
openssl s_client -connect tmarcos.42.fr:443 -tls1_3 < /dev/null 2>&1 | grep -E "Protocol|CONNECTED"
openssl s_client -connect tmarcos.42.fr:443 -tls1_1 < /dev/null 2>&1 | grep "error\|alert"

# 10. Entrar na base de dados
docker exec -it inception-mariadb-1 mariadb -u tmarcos -ptmarcos123 tmarcosdb
# Dentro: SHOW TABLES; SELECT user_login FROM wp_users; EXIT

# 11. Teste de persistência
# Criar post no WordPress...
make down
sudo reboot
# Após reboot:
cd ~/Inception && make
# Verificar que o post ainda existe
```

---

### Cheat sheet de comandos úteis

```bash
# Ver logs em tempo real
make logs

# Ver status dos containers
docker compose -p inception ps

# Entrar dentro de um container
docker exec -it inception-mariadb-1 bash
docker exec -it inception-wordpress-1 bash
docker exec -it inception-nginx-1 bash

# Ver ficheiros no volume do WordPress
ls -la /home/tmarcos/data/wordpress/

# Ver ficheiros no volume do MariaDB
ls -la /home/tmarcos/data/db/

# Ver utilizadores WordPress via wp-cli
docker exec inception-wordpress-1 wp user list --allow-root

# Inspecionar uma image construída
docker image inspect mariadb

# Ver layers de uma image
docker history mariadb
```
