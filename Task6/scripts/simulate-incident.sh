#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_command kubectl

NAMESPACE="secure-ops"
ORIGINAL_NAMESPACE="$(kubectl config view --minify -o 'jsonpath={..namespace}' 2>/dev/null || true)"

restore_namespace() {
    local target="${ORIGINAL_NAMESPACE:-default}"
    kubectl config set-context --current --namespace="$target" >/dev/null
}
trap restore_namespace EXIT

echo "=== Симуляция инцидентов безопасности ==="

echo "[1/6] Создание namespace и переключение контекста..."
kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
EOF
kubectl config set-context --current --namespace="$NAMESPACE" >/dev/null

echo "[2/6] Создание service account и базового пода..."
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: monitoring
EOF

kubectl apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: attacker-pod
spec:
  containers:
  - name: attacker
    image: alpine
    command: ["sleep", "3600"]
  restartPolicy: Never
EOF

echo "[3/6] Проверка доступа к secrets kube-system..."
SECRET_NAME="$(kubectl get secrets -n kube-system -o jsonpath='{.items[?(@.type=="kubernetes.io/service-account-token")].metadata.name}' 2>/dev/null | awk '{print $1}')"
if [[ -n "$SECRET_NAME" ]]; then
    kubectl get secret "$SECRET_NAME" -n kube-system --as="system:serviceaccount:$NAMESPACE:monitoring" >/dev/null 2>&1 || true
else
    echo "Секрет с токеном не найден, шаг пропущен."
fi

echo "[4/6] Создание привилегированного пода..."
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
spec:
  containers:
  - name: pwn
    image: alpine
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
  restartPolicy: Never
EOF

echo "[5/6] Попытка kubectl exec в pod kube-system..."
COREDNS_POD="$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -n "$COREDNS_POD" ]]; then
    kubectl exec -n kube-system "$COREDNS_POD" -- cat /etc/resolv.conf >/dev/null 2>&1 || true
else
    echo "CoreDNS pod не найден, шаг пропущен."
fi

echo "[6/6] Создание RoleBinding с правами cluster-admin..."
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: escalate-binding
subjects:
- kind: ServiceAccount
  name: monitoring
  namespace: secure-ops
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

echo ""
echo "=== Симуляция завершена ==="
echo "Созданы объекты в namespace ${NAMESPACE}:"
echo "  - ServiceAccount monitoring"
echo "  - Pod attacker-pod"
echo "  - Pod privileged-pod"
echo "  - RoleBinding escalate-binding (cluster-admin)"
echo ""
echo "Для анализа audit.log запустите:"
echo "  make copy-log"
echo "  make analyze"
