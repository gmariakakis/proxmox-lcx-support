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
export BOOTSTRAP_SECRET=mysecret
./bootstrap-api
```

```
POST /provision HTTP/1.1
Authorization: Bearer <jwt>
```

The response contains the new VMID and admin token.

For full usage instructions see the [docs](docs/).
