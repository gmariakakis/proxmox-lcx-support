#!/bin/sh
# shellcheck shell=sh disable=SC3040
set -euo pipefail
IFS='
'

# Rotate Matrix Synapse signing keys

docker exec synapse python -m synapse.app.rotate_signing_keys -c /data/homeserver.yaml
