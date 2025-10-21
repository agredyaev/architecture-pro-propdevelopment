#!/bin/bash
set -euo pipefail

NAMESPACE="demo-network-policies"
TIMEOUT=2

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_section() {
    printf '\n======================================\n%s\n======================================\n\n' "$1"
}

test_connectivity() {
    local source_pod="$1"
    local target_service="$2"
    local expected="$3"
    local test_name="$source_pod → $target_service"

    printf 'Тест: %s ... ' "$test_name"

    if kubectl exec -n "$NAMESPACE" "$source_pod" -- wget -qO- --timeout="$TIMEOUT" "http://$target_service" >/dev/null 2>&1; then
        if [[ "$expected" == "allow" ]]; then
            printf '%b\n' "${GREEN}✓ PASS (разрешено)${NC}"
            return 0
        fi
        printf '%b\n' "${RED}✗ FAIL (должно быть запрещено)${NC}"
        return 1
    else
        if [[ "$expected" == "deny" ]]; then
            printf '%b\n' "${GREEN}✓ PASS (запрещено)${NC}"
            return 0
        fi
        printf '%b\n' "${RED}✗ FAIL (должно быть разрешено)${NC}"
        return 1
    fi
}

run_test() {
    if test_connectivity "$1" "$2" "$3"; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
}

printf '==================================\nNetwork Policies Testing Script\n==================================\n\n'

printf '%b' "${YELLOW}Проверка namespace...${NC}\n"
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    printf '%b' "${RED}ОШИБКА: Namespace $NAMESPACE не существует${NC}\n"
    exit 1
fi
printf '%b\n\n' "${GREEN}✓ Namespace существует${NC}"

printf '%b' "${YELLOW}Проверка подов...${NC}\n"
REQUIRED_PODS=("front-end-app" "back-end-api-app" "admin-front-end-app" "admin-back-end-api-app")
for pod in "${REQUIRED_PODS[@]}"; do
    if ! kubectl get pod "$pod" -n "$NAMESPACE" >/dev/null 2>&1; then
        printf '%b\n' "${RED}ОШИБКА: Pod $pod не существует${NC}"
        exit 1
    fi
    POD_STATUS=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
    if [[ "$POD_STATUS" != "Running" ]]; then
        printf '%b\n' "${RED}ОШИБКА: Pod $pod не в статусе Running (текущий: $POD_STATUS)${NC}"
        exit 1
    fi
    printf '%b\n' "${GREEN}✓ Pod $pod запущен${NC}"
done
printf '\n'

printf '%b' "${YELLOW}Проверка Network Policies...${NC}\n"
POLICIES=$(kubectl get networkpolicies -n "$NAMESPACE" -o name | wc -l)
if [[ "$POLICIES" -eq 0 ]]; then
    printf '%b\n' "${RED}ВНИМАНИЕ: Network Policies не найдены${NC}"
else
    printf '%b\n' "${GREEN}✓ Найдено $POLICIES Network Policies${NC}"
    kubectl get networkpolicies -n "$NAMESPACE"
fi
printf '\n'

PASSED=0
FAILED=0

print_section "Тестирование клиентских сервисов"
run_test "front-end-app" "back-end-api-app" "allow"
printf '%b\n' "${YELLOW}Тест: back-end-api-app → front-end-app (не проверяется, соединение инициирует UI)${NC}"
run_test "front-end-app" "admin-back-end-api-app" "deny"
run_test "front-end-app" "admin-front-end-app" "deny"

print_section "Тестирование административных сервисов"
run_test "admin-front-end-app" "admin-back-end-api-app" "allow"
run_test "admin-front-end-app" "back-end-api-app" "deny"
run_test "admin-front-end-app" "front-end-app" "deny"

print_section "Тестирование перекрестной изоляции"
run_test "back-end-api-app" "admin-back-end-api-app" "deny"
run_test "admin-back-end-api-app" "back-end-api-app" "deny"

print_section "Результаты тестирования"
printf 'Пройдено: %b%s%b\n' "${GREEN}" "$PASSED" "${NC}"
printf 'Провалено: %b%s%b\n' "${RED}" "$FAILED" "${NC}"
printf 'Всего тестов: %s\n\n' "$((PASSED + FAILED))"

if [[ "$FAILED" -eq 0 ]]; then
    printf '%b\n' "${GREEN}✓ Все тесты пройдены успешно!${NC}"
    exit 0
fi

printf '%b\n' "${RED}✗ Некоторые тесты провалились${NC}"
printf '\nРекомендации по устранению:\n'
printf '1. kubectl get netpol -n %s\n' "$NAMESPACE"
printf '2. kubectl get pods -n %s --show-labels\n' "$NAMESPACE"
printf '3. kubectl describe netpol -n %s <name>\n' "$NAMESPACE"
exit 1
