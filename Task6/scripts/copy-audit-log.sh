#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_command kubectl

CLUSTER_TYPE="$(detect_cluster_type)"
TARGET_LOG="$TASK6_ROOT/audit.log"
AUDIT_SRC="/var/log/kubernetes/audit.log"

case "$CLUSTER_TYPE" in
    k3s)
        if [[ -r "$AUDIT_SRC" ]]; then
            cp "$AUDIT_SRC" "$TARGET_LOG"
        elif command -v sudo >/dev/null 2>&1; then
            sudo cp "$AUDIT_SRC" "$TARGET_LOG"
            sudo chown "$(id -u)":"$(id -g)" "$TARGET_LOG"
        else
            printf 'Не удалось прочитать %s. Запустите скрипт с sudo.\n' "$AUDIT_SRC" >&2
            exit 1
        fi
        ;;
    *)
        printf 'Автокопирование поддерживает только k3s. Обнаружено: %s\n' "$CLUSTER_TYPE" >&2
        exit 1
        ;;
esac

if [[ ! -f "$TARGET_LOG" ]]; then
    printf 'Копирование audit log не удалось.\n' >&2
    exit 1
fi

printf 'Аудит-лог сохранён в %s (%s строк)\n' "$TARGET_LOG" "$(wc -l < "$TARGET_LOG")"
