#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TMP_OUTPUT="$(mktemp)"
trap 'rm -f "$TMP_OUTPUT"' EXIT

main() {
    print_header "Проверка политик безопасности контейнеров"
    require_command kubectl
    require_command jq

    ensure_cluster

    echo "Шаг 1: применение namespace"
    kubectl apply -f "$PROJECT_DIR/01-create-namespace.yaml" >/dev/null
    echo "Namespace audit-zone применён"
    echo

    echo "Шаг 2: проверка PodSecurity меток"
    namespace_json=$(kubectl get namespace audit-zone -o json)
    if echo "$namespace_json" | jq -e '.metadata.labels["pod-security.kubernetes.io/enforce"]' >/dev/null; then
        echo "$namespace_json" | jq '.metadata.labels'
    else
        echo "Предупреждение: не найдены метки PodSecurity Admission"
    fi
    echo

    echo "Шаг 3: проверка OPA Gatekeeper"
    if kubectl get constrainttemplate >/dev/null 2>&1; then
        kubectl apply -f "$PROJECT_DIR/gatekeeper/constraint-templates/" >/dev/null
        kubectl apply -f "$PROJECT_DIR/gatekeeper/constraints/" >/dev/null
        echo "Gatekeeper политики применены"
    else
        echo "Предупреждение: Gatekeeper не установлен. Примените официальный манифест и повторите запуск."
    fi
    echo

    print_header "Тестирование небезопасных манифестов"
    expect_denied "$PROJECT_DIR/insecure-manifests/01-privileged-pod.yaml"
    expect_denied "$PROJECT_DIR/insecure-manifests/02-hostpath-pod.yaml"
    expect_denied "$PROJECT_DIR/insecure-manifests/03-root-user-pod.yaml"
    echo

    print_header "Тестирование безопасных манифестов"
    expect_allowed "$PROJECT_DIR/secure-manifests/01-secure.yaml"
    expect_allowed "$PROJECT_DIR/secure-manifests/02-secure.yaml"
    expect_allowed "$PROJECT_DIR/secure-manifests/03-secure.yaml"
    echo

    print_header "Статус подов"
    kubectl get pods -n audit-zone
    echo

    print_header "Итог"
    echo "Проверки завершены"
}

print_header() {
    printf '%s\n' "========================================"
    printf '%s\n' "$1"
    printf '%s\n' "========================================"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || { printf 'ERROR: %s not found\n' "$1" >&2; exit 1; }
}

ensure_cluster() {
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "Кластер Kubernetes доступен"
        echo
        return
    fi

    printf 'ERROR: кластер недоступен. Проверьте kubeconfig и состояние control plane.\n' >&2
    exit 1
}

expect_denied() {
    local manifest="$1"
    if kubectl apply -f "$manifest" >"$TMP_OUTPUT" 2>&1; then
        printf 'ERROR: %s был применён, но ожидался отказ\n' "$manifest" >&2
        cat "$TMP_OUTPUT" >&2
        exit 1
    fi
    if ! grep -qiE 'denied|forbidden|violates' "$TMP_OUTPUT"; then
        printf 'ERROR: %s отклонён без пояснения\n' "$manifest" >&2
        cat "$TMP_OUTPUT" >&2
        exit 1
    fi
    printf 'Отклонён как ожидалось: %s\n' "$manifest"
}

expect_allowed() {
    local manifest="$1"
    if kubectl apply -f "$manifest" >/dev/null; then
        printf 'Применён: %s\n' "$manifest"
    else
        printf 'ERROR: не удалось применить %s\n' "$manifest" >&2
        exit 1
    fi
}

main "$@"
