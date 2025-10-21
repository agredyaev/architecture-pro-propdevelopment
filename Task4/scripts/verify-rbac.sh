#!/bin/bash
set -euo pipefail

NAMESPACES=(sales tenant-services finance data)

declare -A TESTS=(
  [developer_sales]="kubectl auth can-i get secrets -n sales --as=system:serviceaccount:sales:developer-sales"
  [devops_cross_ns]="kubectl auth can-i create deployment -n finance --as=system:serviceaccount:sales:devops-sales"
  [viewer_delete_pod]="kubectl auth can-i delete pods --as=system:serviceaccount:default:business-viewer"
  [sre_patch_deploy]="kubectl auth can-i patch deployment -n sales --as=system:serviceaccount:sales:sre-sales"
)

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

run_check() {
  local name="$1"
  local cmd="$2"

  if eval "$cmd" >/dev/null 2>&1; then
    case "$name" in
      developer_sales|devops_cross_ns|viewer_delete_pod)
        printf '%b%s%b -> ожидается forbidden, получено allow\n' "$RED" "$name" "$NC"
        return 1
        ;;
      *)
        printf '%b%s%b -> OK\n' "$GREEN" "$name" "$NC"
        return 0
        ;;
    esac
  else
    case "$name" in
      sre_patch_deploy)
        printf '%b%s%b -> ожидается allow, получено forbidden\n' "$RED" "$name" "$NC"
        return 1
        ;;
      *)
        printf '%b%s%b -> OK\n' "$GREEN" "$name" "$NC"
        return 0
        ;;
    esac
  fi
}

failures=0
for name in "${!TESTS[@]}"; do
  run_check "$name" "${TESTS[$name]}" || failures=$((failures + 1))
done

if [[ $failures -gt 0 ]]; then
  echo "Errors detected"
  exit 1
fi

echo "RBAC checks passed"
