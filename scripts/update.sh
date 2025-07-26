#!/bin/sh
# shellcheck shell=sh disable=SC3040
set -euo pipefail
IFS='
'

cd /opt/chat

docker compose pull
systemctl restart chat-stack.service
