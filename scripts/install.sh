#!/usr/bin/env bash
# shellcheck disable=SC3040,SC2012
#
# install.sh – Provision a secure Matrix/Synapse + Element stack
#              in an unprivileged LXC on Proxmox.
#
# Usage examples
#   sudo ./install.sh                     # defaults
#   sudo ./install.sh --vmid 350 --template debian --hostname chat
#
set -euo pipefail
IFS=$'\n\t'

###############################################################################
#  CLI options
###############################################################################
VMID=350
TEMPLATE=ubuntu          # ubuntu‑22.04 or debian‑12 cached tar.zst
HOSTNAME=chat
PASSWORD=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --vmid)      VMID=$2;       shift 2 ;;
    --template)  TEMPLATE=$2;   shift 2 ;;
    --hostname)  HOSTNAME=$2;   shift 2 ;;
    --password)  PASSWORD=$2;   shift 2 ;;
    *) echo "Unknown option $1" >&2; exit 1 ;;
  esac
done

[[ -z $PASSWORD ]] && PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

###############################################################################
#  Locate template
###############################################################################
case $TEMPLATE in
  ubuntu)  IMAGE=$(ls /var/lib/vz/template/cache/*ubuntu-22.04*tar.zst | head -n1) ;;
  debian)  IMAGE=$(ls /var/lib/vz/template/cache/*debian-12*tar.zst   | head -n1) ;;
  *) echo "Invalid template" >&2; exit 1 ;;
esac
[[ -z $IMAGE ]] && { echo "Template image not found."; exit 1; }

###############################################################################
#  Create and start LXC
###############################################################################
pct create "$VMID" "$IMAGE" \
  --hostname "$HOSTNAME" \
  --storage local-lvm \
  --rootfs local-lvm:8 \
  --password "$PASSWORD" \
  --unprivileged 1 \
  --features nesting=1,keyctl=1,fuse=1 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp

pct start "$VMID"
sleep 5

###############################################################################
#  Bootstrap inside the container
###############################################################################
pct exec "$VMID" -- bash -eu <<'INNER'
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-plugin curl iptables iptables-persistent
systemctl disable --now ssh || true

# Harden IPTables (example – adapt as‑needed)
iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 80  -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Persist IPTables rules
iptables-save >/etc/iptables/rules.v4

mkdir -p /opt/chat
INNER

###############################################################################
#  Generate secrets
###############################################################################
DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
REG_SECRET=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32)
TOKEN1=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
TOKEN2=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

###############################################################################
#  Write stack files
###############################################################################
pct exec "$VMID" -- bash -s <<INNER
cat >/opt/chat/.env <<EOF
SERVER_NAME=$HOSTNAME
DB_PASSWORD=$DB_PASSWORD
REG_SHARED_SECRET=$REG_SECRET
REGISTRATION_TOKENS=$TOKEN1,$TOKEN2
EOF

cat >/opt/chat/docker-compose.yml <<'EOF'
version: "3.8"
services:
  db:
    image: postgres:15
    restart: unless-stopped
    environment:
      POSTGRES_USER: synapse
      POSTGRES_PASSWORD: \${DB_PASSWORD}
      POSTGRES_DB: synapse
    volumes:
      - db-data:/var/lib/postgresql/data

  synapse:
    image: matrixdotorg/synapse:latest
    restart: unless-stopped
    depends_on: [db, clamav]
    environment:
      SYNAPSE_SERVER_NAME: \${SERVER_NAME}
      SYNAPSE_REPORT_STATS: "no"
      SYNAPSE_REGISTRATION_SHARED_SECRET: \${REG_SHARED_SECRET}
      SYNAPSE_MAX_UPLOAD_SIZE: 100M
      POSTGRES_DB: synapse
      POSTGRES_USER: synapse
      POSTGRES_PASSWORD: \${DB_PASSWORD}
      POSTGRES_HOST: db
      POSTGRES_PORT: 5432
    volumes:
      - synapse-data:/data

  element:
    image: vectorim/element-web:latest
    restart: unless-stopped

  clamav:
    image: clamav/clamav:latest
    restart: unless-stopped
    volumes:
      - clamav-db:/var/lib/clamav

  caddy:
    image: caddy:latest
    restart: unless-stopped
    depends_on: [element]
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - caddy-data:/data
      - caddy-config:/config
      - ./Caddyfile:/etc/caddy/Caddyfile:ro

volumes:
  db-data:
  synapse-data:
  caddy-data:
  caddy-config:
  clamav-db:
EOF

cat >/opt/chat/Caddyfile <<'EOF'
:80 {
  redir https://{host}{uri} permanent
}
:443 {
  reverse_proxy synapse:8008
  handle_path /_matrix/* {
        reverse_proxy synapse:8008
  }
  handle {
        reverse_proxy element:80
  }
  tls {
        protocols tls1.3
  }
  header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
}
EOF

cat >/etc/systemd/system/chat-stack.service <<'EOF'
[Unit]
Description=Chat Stack
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/opt/chat
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now chat-stack.service
INNER

###############################################################################
#  Save root secrets to file (display once)
###############################################################################
pct exec "$VMID" -- bash -c "cat >/root/SECRETS.txt <<EOF
ROOT_PASSWORD=$PASSWORD
DB_PASSWORD=$DB_PASSWORD
REG_SHARED_SECRET=$REG_SECRET
REGISTRATION_TOKENS=$TOKEN1,$TOKEN2
EOF
chmod 600 /root/SECRETS.txt"

pct exec "$VMID" -- cat /root/SECRETS.txt
echo "✅  LXC $VMID with Matrix/Element stack is up.   Secrets shown above."
