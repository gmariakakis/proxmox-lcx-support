#!/bin/sh
# shellcheck shell=sh disable=SC3040
set -euo pipefail
SCRIPT_DIR="$(dirname "$0")"
"$SCRIPT_DIR/scripts/install.sh" "$@"
