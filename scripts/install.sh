#!/usr/bin/env bash
set -euo pipefail

HOSTNAME=${1:-}

if [ -z "$HOSTNAME" ]; then
  echo "Usage: $0 <hostname>" >&2
  exit 1
fi

cat > Caddyfile <<CADDY
${HOSTNAME} {
    handle_path /_matrix/* {
        reverse_proxy synapse:8008
    }

    handle {
        reverse_proxy element:80
    }
}
CADDY

cat > docker-compose.yml <<COMPOSE
version: "3.8"
services:
  element:
    image: vectorim/element-web:latest
    restart: unless-stopped

  synapse:
    image: matrixdotorg/synapse:latest
    environment:
      - SYNAPSE_SERVER_NAME=${HOSTNAME}
    volumes:
      - ./synapse:/data
    restart: unless-stopped

  caddy:
    image: caddy:latest
    depends_on:
      - element
      - synapse
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
    ports:
      - "80:80"
      - "443:443"
    restart: unless-stopped
COMPOSE

printf "Caddyfile and docker-compose.yml generated.\n"
