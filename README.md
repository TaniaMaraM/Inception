PASSO 1 — Estrutura do projeto.
├── Makefile
├── srcs/
│   ├── docker-compose.yml
│   ├── .env
│   └── requirements/
│       ├── nginx/
│       ├── wordpress/
│       └── mariadb/

PASSO 2 — Docker Compose
Você vai definir 3 serviços:
* nginx
* wordpress
* mariadb

E também:
* volumes (2)
* network

PASSO 3 — MariaDB (o coração)

Cria:
* Dockerfile
* script de init (criar DB e user)

📌 Tem que:
usar Alpine ou Debian (penultimate version)
NÃO pode usar imagem pronta
usar variáveis do .env

📌 Tem que criar:
database
user
senha segura

🌐 PASSO 4 — WordPress + PHP-FPM
NÃO pode ter nginx aqui
instala PHP + php-fpm
baixa WordPress
conecta com MariaDB

📌 Tem que:
criar 2 usuários:
admin (SEM “admin” no nome)
user normal

🔒 PASSO 5 — NGINX + SSL
Porta 443 ONLY
TLS 1.2 ou 1.3 obrigatório

📌 Faz:
gerar certificado self-signed
configurar reverse proxy pro WordPress

💾 PASSO 6 — Volumes

2 volumes obrigatórios:
banco de dados
arquivos do WordPress

📌 DEVEM estar em:
/home/login/data/

📌 E tem que ser:
named volumes (não bind mount)

🌐 PASSO 7 — Docker Network
cria network no docker-compose
conecta todos os serviços

📌 NÃO pode:
network: host

PASSO 8 — Makefile

Tem que rodar:
make up
make down
make build

🔐 PASSO 9 — .env

Tudo sensível vai aqui:
MYSQL_ROOT_PASSWORD=...
MYSQL_PASSWORD=...
DOMAIN_NAME=login.42.fr

📌 Se tiver senha no repo → 0 direto

PASSO 10 — Domínio local

Edita:
/etc/hosts
127.0.0.1 login.42.fr

🔁 PASSO 11 — Teste de persistência
sobe projeto
muda algo no WP
reinicia VM
tudo deve continuar lá

📌 Se perder dados → FAIL

Explicação simples:

Docker é tipo um “processo isolado”, VM é tipo “outro computador inteiro”

🧩 Docker Image vs Container
Image → blueprint
Container → execução
🔗 Docker Compose
gerencia múltiplos containers
define infra em YAML
🌐 Docker Network
permite containers conversarem por nome

Ex:
wordpress → mariadb

Volumes vs Bind Mount
Volume	Bind
gerenciado pelo Docker	caminho manual
mais seguro	mais flexível

📌 Projeto exige volume

🔐 Environment Variables vs Secrets
.env → config
secrets → dados sensíveis
🔄 PHP-FPM
executa PHP
funciona com NGINX (não Apache)
🌍 NGINX
servidor web
faz reverse proxy
🔒 SSL/TLS
criptografia HTTPS
obrigatório no projeto
🧠 PID 1 (pegadinha clássica)

Container roda 1 processo principal.

📌 Não pode:

tail -f
sleep infinity
🔥 ERROS QUE TE REPROVAM NA HORA
usar DockerHub ❌
usar latest ❌
usar --link ❌
senha no repo ❌
nginx fora do container ❌
HTTP funcionando ❌
sem TLS ❌


Prompt:
You are a senior DevOps engineer helping me build the 42 Inception project.

Context:

* I must build a Docker-based infrastructure with NGINX, WordPress (php-fpm), and MariaDB.
* I am NOT allowed to use pre-built images except Alpine/Debian base.
* I must write my own Dockerfiles.
* I must use docker-compose.
* I must use a .env file for all environment variables.
* I must NOT include secrets in the repository.
* I must use Docker networks (no host, no links).
* I must use named volumes stored in /home/login/data.
* NGINX must be the only entry point on port 443 with TLS 1.2/1.3.
* No infinite loops, no tail -f, no bash as main process.

Your role:

* Explain step-by-step what to do WITHOUT giving me full copy-paste solutions.
* Help me understand each part so I can explain it during evaluation.
* When suggesting code, explain what every line does.
* Ask me questions to ensure I understand.

Goal:
I want to deeply understand Docker, networking, volumes, and services so I can defend the project confidently.
