#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_command kubectl

CLUSTER_TYPE="$(detect_cluster_type)"
AUDIT_POLICY_SRC="$TASK6_ROOT/audit-policy.yaml"

if [[ "$CLUSTER_TYPE" != "k3s" ]]; then
    printf 'Setup поддерживает только кластер k3s. Обнаружено: %s\n' "$CLUSTER_TYPE" >&2
    printf 'Настройте аудит вручную согласно README.\n'
    exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
    printf 'Для настройки k3s требуется запуск с sudo.\n' >&2
    exit 1
fi

AUDIT_DEST="/etc/rancher/k3s/audit-policy.yaml"
CONFIG_DEST="/etc/rancher/k3s/config.yaml"
LOG_DIR="/var/log/kubernetes"

install -d -m 755 "$(dirname "$AUDIT_DEST")"
install -d -m 755 "$LOG_DIR"
install -m 644 "$AUDIT_POLICY_SRC" "$AUDIT_DEST"

cat > "$CONFIG_DEST" <<'EOF'
kube-apiserver-arg:
  - audit-policy-file=/etc/rancher/k3s/audit-policy.yaml
  - audit-log-path=/var/log/kubernetes/audit.log
  - audit-log-maxage=30
  - audit-log-maxbackup=3
  - audit-log-maxsize=100
EOF

systemctl restart k3s

printf 'Audit logging включён. Лог: %s\n' "$LOG_DIR/audit.log"
