#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK6_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf 'ERROR: команда %s не найдена. Установите её и повторите.\n' "$cmd" >&2
        exit 1
    fi
}

detect_cluster_type() {
    if systemctl is-active --quiet k3s 2>/dev/null; then
        echo "k3s"
        return
    fi
    echo "unknown"
}
