#!/bin/bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-audit-zone}"

require_command() {
    command -v "$1" >/dev/null 2>&1 || { printf 'ERROR: %s not found\n' "$1" >&2; exit 1; }
}

print_header() {
    printf '%s\n' "========================================"
    printf '%s\n' "$1"
    printf '%s\n' "========================================"
}

check_pods() {
    local pods_json violations=0
    if ! pods_json="$(kubectl get pods -n "$NAMESPACE" -o json 2>/dev/null)"; then
        echo "Ошибка обращения к API сервера. Проверьте kubeconfig и доступность кластера."
        return 2
    fi

    if [ "$(echo "$pods_json" | jq '.items | length')" -eq 0 ]; then
        echo "В namespace $NAMESPACE нет подов"
        return 0
    fi

    while IFS=$'\t' read -r name privileged run_as_non_root run_as_root read_only host_path; do
        echo "Проверка пода: $name"

        if [ "$privileged" = "true" ]; then
            echo "Нарушение: privileged=true"
            violations=$((violations + 1))
        else
            echo "Privileged отключён"
        fi

        if [ "$run_as_non_root" = "true" ]; then
            echo "runAsNonRoot включён"
        else
            echo "Нарушение: runAsNonRoot != true"
            violations=$((violations + 1))
        fi

        if [ "$run_as_root" = "true" ]; then
            echo "Нарушение: runAsUser=0"
            violations=$((violations + 1))
        else
            echo "Контейнер не запускается от root"
        fi

        if [ "$read_only" = "true" ]; then
            echo "readOnlyRootFilesystem включён"
        else
            echo "Нарушение: readOnlyRootFilesystem != true"
            violations=$((violations + 1))
        fi

        if [ "$host_path" = "true" ]; then
            echo "Нарушение: присутствует hostPath volume"
            violations=$((violations + 1))
        else
            echo "hostPath не используется"
        fi

        echo
    done < <(
        echo "$pods_json" | jq -r '
            .items[] |
            def containers: (.spec.containers // []) + (.spec.initContainers // []) + (.spec.ephemeralContainers // []);
            [
                .metadata.name,
                (any(containers[]?; .securityContext.privileged == true)),
                (all(containers[]?; .securityContext.runAsNonRoot == true)),
                (any(containers[]?; .securityContext.runAsUser == 0)),
                (all(containers[]?; .securityContext.readOnlyRootFilesystem == true)),
                (any((.spec.volumes // [])[]?; has("hostPath")))
            ] | @tsv
        '
    )

    echo "Нарушений обнаружено: $violations"
    return $violations
}

check_gatekeeper() {
    if ! kubectl get constraints >/dev/null 2>&1; then
        echo "Gatekeeper не установлен или CRD недоступны"
        return
    fi

    echo "ConstraintTemplates:"
    kubectl get constrainttemplates
    echo
    echo "Constraints:"
    kubectl get constraints --all-namespaces
    echo
    echo "Нарушения:"
    kubectl get constraints -o json | jq -r '.items[] | select(.status.totalViolations > 0) | "\(.metadata.name): \(.status.totalViolations)"'
}

main() {
    require_command kubectl
    require_command jq

    print_header "Аудит подов"
    if check_pods; then
        pod_rc=0
    else
        pod_rc=$?
    fi

    if [ "$pod_rc" -eq 2 ]; then
        echo
        print_header "Gatekeeper"
        echo "Проверка Gatekeeper пропущена из-за недоступности API сервера"
        echo
        echo "Проверка остановлена из-за ошибок подключения к API серверу"
        exit 1
    fi

    echo
    print_header "Gatekeeper"
    check_gatekeeper
    echo

    if [ "$pod_rc" -eq 0 ]; then
        echo "Нарушений не обнаружено"
        exit 0
    fi

    echo "Найдены нарушения: $pod_rc"
    exit 1
}

main "$@"
