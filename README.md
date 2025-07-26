# proxmox-lcx-support

This repository contains helper scripts for deploying the Element web interface using Docker and serving it with Caddy.

## Installation

Run the install script with the hostname that should be used for automatic HTTPS certificates:

```bash
./scripts/install.sh example.com
```

The script generates a `Caddyfile` and `docker-compose.yml` configured to serve the Element static files.
