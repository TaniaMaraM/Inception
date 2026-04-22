# Named Volumes vs Bind Mounts — Evaluation Defence

> This document explains why `o: bind` inside a named volume definition does **not**
> violate the subject rule *"Bind mounts are not allowed for these volumes."*

---

## The rule (subject v5.2, p.7)

> "You must use Docker named volumes for these two persistent storages.
> Bind mounts are not allowed for these volumes."

---

## What the evaluator may say — and how to answer

---

### Objection 1 — "That's a bind mount, I can see `o: bind` right there."

**Your answer:**

There are two completely different things in Docker that use the word "bind":

| Concept | Where it appears | What it is |
|---|---|---|
| **Bind mount** | Inside a service's `volumes:` list | A Docker storage type |
| **`o: bind`** | Inside a volume's `driver_opts:` | A Linux kernel `mount` flag |

A **bind mount** (forbidden) looks like this — it lives **inside the service block**:

```yaml
# FORBIDDEN — this is a bind mount
services:
  wordpress:
    volumes:
      - /home/tmarcos/data/wordpress:/var/www/html
```

What the project uses is a **named volume** — it lives in the top-level `volumes:` block and has a name:

```yaml
# ALLOWED — this is a named volume
volumes:
  wp-files:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/tmarcos/data/wordpress
```

The `o: bind` is an option passed to the Linux `mount` command under the hood. It is the same as writing `mount -t none -o bind /home/tmarcos/data/wordpress /mountpoint`. It controls **how the kernel links the directory**, not **what type of Docker object the volume is**.

---

### Objection 2 — "Prove it's a named volume and not a bind mount."

**Your answer — run this live:**

```bash
docker volume ls
```

Expected output:

```
DRIVER    VOLUME NAME
local     srcs_wp-db
local     srcs_wp-files
```

**Bind mounts never appear in `docker volume ls`.** Named volumes always do.
This is the definitive Docker distinction.

For even more detail:

```bash
docker volume inspect srcs_wp-files
```

Expected output:

```json
[
    {
        "CreatedAt": "...",
        "Driver": "local",
        "Labels": { ... },
        "Mountpoint": "/var/lib/docker/volumes/srcs_wp-files/_data",
        "Name": "srcs_wp-files",
        "Options": {
            "device": "/home/tmarcos/data/wordpress",
            "o": "bind",
            "type": "none"
        },
        "Scope": "local"
    }
]
```

Docker manages this volume. It has a name, a driver, and an entry in Docker's own registry.
A bind mount has none of that — it is just a path.

---

### Objection 3 — "Why not use a plain named volume without `o: bind`?"

**Your answer:**

The subject also says (p.7):

> *"Both named volumes must store their data inside `/home/login/data` on the host machine."*

A plain named volume (no `driver_opts`) stores data here:

```
/var/lib/docker/volumes/srcs_wp-files/_data
```

You cannot change that path without `driver_opts`. The **only Docker-native way** to make a named volume store its data at a specific host path (like `/home/tmarcos/data/wordpress`) is to use the `local` driver with `type: none`, `o: bind`, and `device: <path>`.

The two constraints together — named volume + specific host path — **force** this exact configuration.

---

### Objection 4 — "But semantically, it's the same as a bind mount."

**Your answer:**

Semantically they are similar — both expose a host directory to a container. But the subject's prohibition is about **Docker volume type**, not kernel semantics. The distinction Docker itself makes is:

- **Bind mount** → created inline in a service, not managed by Docker, invisible to `docker volume ls`
- **Named volume** → declared with a name, managed by Docker, visible to `docker volume ls`, can be shared between services by name

The volumes `wp-db` and `wp-files` are shared between the `wordpress` and `nginx` services **by name**:

```yaml
# docker-compose.yml
wordpress:
  volumes:
    - wp-files:/var/www/html   # referenced by name

nginx:
  volumes:
    - wp-files:/var/www/html   # same volume, referenced by name
```

You cannot do this with a bind mount — you'd have to duplicate the host path in both services and Docker would not track it as a shared resource. This is exactly the use case named volumes are designed for.

---

## Visual summary

```
BIND MOUNT (forbidden)
┌─────────────────────────────────────────┐
│ services:                               │
│   wordpress:                            │
│     volumes:                            │
│       - /host/path:/container/path  ←── │── raw path, no name, not in docker volume ls
└─────────────────────────────────────────┘

NAMED VOLUME (what the project uses)
┌─────────────────────────────────────────┐
│ services:                               │
│   wordpress:                            │
│     volumes:                            │
│       - wp-files:/var/www/html      ←── │── referenced by name
│                                         │
│ volumes:                                │
│   wp-files:                         ←── │── declared with a name
│     driver: local                       │
│     driver_opts:                        │
│       type: none                        │
│       o: bind           ←── Linux mount flag, not Docker type
│       device: /home/tmarcos/data/wordpress
└─────────────────────────────────────────┘
```

---

## One-line summary for evaluators

> "The volumes are named — they appear in `docker volume ls`, are managed by Docker,
> and are referenced by name. The `o: bind` is a Linux `mount` flag that controls where
> the local driver stores the data. The subject requires both: a named volume AND data
> at `/home/tmarcos/data`. This configuration is the only way to satisfy both at once."
