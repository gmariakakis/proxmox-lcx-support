# gxenon-signal-lxc

`gxenon-signal-lxc` provides a one command deployment of a hardened Matrix stack on Proxmox using LXC. It installs Matrix Synapse, Element Web served by Caddy with automatic HTTPS, and an optional bootstrap API for provisioning additional containers.

![diagram](docs/diagram.png)

## Quick start

```bash
./install.sh --vmid 350 --template ubuntu --hostname chat
```

The script creates an unprivileged container and prints generated credentials and registration tokens. These values are also stored in `/root/SECRETS.txt` inside the container.

### Requirements

- Proxmox host with existing LXC templates in `/var/lib/vz/template/cache/`
- Internet access for the container to install packages

### Bootstrap API

The optional API listens on `127.0.0.1:8787` and provisions new containers on demand:

```bash
expor BOOTSTRAP_SECRET=mysecret
./bootstrap-api
```

```
POST /provision HTTP/1.1
Authorization: Bearer <jwt>
```

The response contains the new VMID and admin token.

For full usage instructions see the [docs](docs/).

## Quick-start on Proxmox host

```bash
# on PVE node
// 7zfnjt-codex/create-open-source-github-repository-gxenon-signal-lxc
git clone https://github.com/gmariakakis/proxmox-lcx-support.git
cd proxmox-lcx-support
sudo ./install.sh -c 204 -d /tank/lxc \
                  --fqdn chat.gxenon.com \
                  --admin-email you@example.com

git clone https://github.com/gxenon/proxmox-lcx-support.git
cd proxmox-lcx-support
sudo ./install.sh --vmid 204 --template debian --hostname chat.example.com
 main


`install.sh` will create a privileged Debian 12 container with nesting and fuse enabled,
install Docker Engine and docker-compose, then deploy the Matrix stack (Synapse,
// 7zfnjt-codex/create-open-source-github-repository-gxenon-signal-lxc
Element, Postgres, Redis, Caddy with Cloudflare origin certs, ClamAV).
It prints a join URL and a Cloudflare Tunnel command for the reverse-proxy.
=======
Element, Postgres, Redis, Caddy with Cloudflare origin certs, ClamAV). It prints a join URL and a Cloudflare Tunnel command for the reverse-proxy.
 main

For advanced automation hit the Go bootstrap API running on `:8088` of the new container:

```bash
curl -XPOST -H "Authorization: Bearer $API_TOKEN" \
     -d '{"template":"matrix","vmid":205,"fqdn":"extra.gxenon.com"}' \
     https://chat-node.local:8088/api/v1/provision
```
