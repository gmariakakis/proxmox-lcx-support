#!/bin/sh
set -euo pipefail
IFS='
'

cd /opt/chat

docker compose pull
systemctl restart chat-stack.service
