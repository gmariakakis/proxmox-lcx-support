#!/usr/bin/env bash
set -euo pipefail

HOSTNAME=${1:-}

if [ -z "$HOSTNAME" ]; then
  echo "Usage: $0 <hostname>" >&2
  exit 1
fi

cat > Caddyfile <<CADDY
${HOSTNAME} {
    root * /usr/share/nginx/html
    file_server
}
CADDY

cat > docker-compose.yml <<'COMPOSE'
version: "3.8"
services:
  element:
    image: vectorim/element-web:latest
    volumes:
      - ./element:/usr/share/nginx/html
    restart: unless-stopped

  caddy:
    image: caddy:latest
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./element:/usr/share/nginx/html:ro
    ports:
      - "80:80"
      - "443:443"
    restart: unless-stopped
COMPOSE

printf "Caddyfile and docker-compose.yml generated.\n"
