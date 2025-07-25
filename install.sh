#!/bin/sh
set -euo pipefail
IFS='
	'
VMID=350
TEMPLATE=ubuntu
HOSTNAME=chat
PASSWORD=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --vmid) VMID=$2; shift 2;;
    --template) TEMPLATE=$2; shift 2;;
    --hostname) HOSTNAME=$2; shift 2;;
    --password) PASSWORD=$2; shift 2;;
    *) echo "Unknown option $1"; exit 1;;
  esac
done
[ -z "$PASSWORD" ] && PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
case "$TEMPLATE" in
  ubuntu) IMAGE=$(ls /var/lib/vz/template/cache/*ubuntu-22.04*tar.zst | head -n1);;
  debian) IMAGE=$(ls /var/lib/vz/template/cache/*debian-12*tar.zst | head -n1);;
  *) echo "Invalid template"; exit 1;;
esac
pct create "$VMID" "$IMAGE" --hostname "$HOSTNAME" --storage local-lvm   --rootfs local-lvm:8 --password "$PASSWORD" --unprivileged 1   --features nesting=1,keyctl=1,fuse=1 --net0 name=eth0,bridge=vmbr0,ip=dhcp
pct start "$VMID"
sleep 5
pct exec "$VMID" -- bash -eu <<'BASH'
apt-get update
apt-get install -y docker.io docker-compose-plugin curl iptables
systemctl disable --now ssh || true
iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
mkdir -p /opt/chat
BASH
DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
REG_SECRET=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32)
TOKEN1=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
TOKEN2=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
pct exec "$VMID" -- bash -c "cat >/opt/chat/.env <<EOF
SERVER_NAME=$HOSTNAME
DB_PASSWORD=$DB_PASSWORD
REG_SHARED_SECRET=$REG_SECRET
REGISTRATION_TOKENS=$TOKEN1,$TOKEN2
EOF"
pct exec "$VMID" -- bash -c "cat >/opt/chat/docker-compose.yml <<'EOF'
version: '3.8'
services:
  db:
    image: postgres:15
    restart: always
    environment:
      POSTGRES_USER: synapse
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: synapse
    volumes:
      - db-data:/var/lib/postgresql/data
  synapse:
    image: matrixdotorg/synapse:latest
    restart: always
    depends_on:
      - db
      - clamav
    environment:
      SYNAPSE_SERVER_NAME: ${SERVER_NAME}
      SYNAPSE_REPORT_STATS: "no"
      SYNAPSE_REGISTRATION_SHARED_SECRET: ${REG_SHARED_SECRET}
      POSTGRES_DB: synapse
      POSTGRES_USER: synapse
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_HOST: db
      POSTGRES_PORT: 5432
    volumes:
      - synapse-data:/data
  element:
    image: vectorim/element-web:latest
    restart: always
  caddy:
    image: caddy:latest
    restart: always
    depends_on:
      - element
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - caddy-data:/data
      - caddy-config:/config
      - ./Caddyfile:/etc/caddy/Caddyfile
  clamav:
    image: clamav/clamav:latest
    restart: always
    volumes:
      - clamav-db:/var/lib/clamav
volumes:
  db-data:
  synapse-data:
  caddy-data:
  caddy-config:
  clamav-db:
EOF"
pct exec "$VMID" -- bash -c "cat >/opt/chat/Caddyfile <<'EOF'
:80 {
  redir https://{host}{uri} permanent
}
:443 {
  reverse_proxy synapse:8008
  tls {
    protocols tls1.3
  }
  header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
}
EOF"
pct exec "$VMID" -- bash -c "cat >/etc/systemd/system/chat-stack.service <<'EOF'
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
systemctl enable --now chat-stack.service"
pct exec "$VMID" -- bash -c "cat >/root/SECRETS.txt <<EOF
ROOT_PASSWORD=$PASSWORD
DB_PASSWORD=$DB_PASSWORD
REG_SHARED_SECRET=$REG_SECRET
REGISTRATION_TOKENS=$TOKEN1,$TOKEN2
EOF"
pct exec "$VMID" -- cat /root/SECRETS.txt
