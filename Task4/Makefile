.DEFAULT_GOAL := help
.PHONY: help status validate apply delete reset test-all test-developer test-devops test-sre test-viewer verify

# --- Settings ---------------------------------------------------------------
KUBECTL ?= kubectl
MANIFEST_DIR := manifests
SCRIPT_DIR := scripts
MANIFESTS := \
	$(MANIFEST_DIR)/10-namespaces-and-users.yaml \
	$(MANIFEST_DIR)/20-clusterroles.yaml \
	$(MANIFEST_DIR)/30-bindings.yaml
GREEN := \033[0;32m
RED := \033[0;31m
NC := \033[0m

##@ Deployment
validate: ## Валидировать манифесты без применения
	@echo "Validating YAML manifests..."
	@for manifest in $(MANIFESTS); do \
		$(KUBECTL) apply -f $$manifest --dry-run=client >/dev/null && \
		echo " - validated $$manifest"; \
	done
	@echo "$(GREEN)✓$(NC) All manifests are valid"

apply: ## Применить RBAC конфигурацию
	@echo "Applying namespaces and users..."
	@$(KUBECTL) apply -f $(MANIFEST_DIR)/10-namespaces-and-users.yaml
	@echo "Applying roles..."
	@$(KUBECTL) apply -f $(MANIFEST_DIR)/20-clusterroles.yaml
	@echo "Applying bindings..."
	@$(KUBECTL) apply -f $(MANIFEST_DIR)/30-bindings.yaml
	@echo "$(GREEN)✓$(NC) RBAC configuration applied"

delete: ## Удалить RBAC ресурсы
	@echo "Deleting RBAC resources..."
	@$(KUBECTL) delete -f $(MANIFEST_DIR)/30-bindings.yaml --ignore-not-found=true
	@$(KUBECTL) delete -f $(MANIFEST_DIR)/20-clusterroles.yaml --ignore-not-found=true
	@$(KUBECTL) delete -f $(MANIFEST_DIR)/10-namespaces-and-users.yaml --ignore-not-found=true
	@echo "$(GREEN)✓$(NC) RBAC resources deleted"

reset: ## Полный сброс (delete + очистка тестовых ресурсов)
	@echo "Full reset..."
	@$(KUBECTL) delete deployment nginx -n sales --ignore-not-found=true 2>/dev/null || true
	@$(KUBECTL) delete service nginx -n sales --ignore-not-found=true 2>/dev/null || true
	@$(KUBECTL) delete -f $(MANIFEST_DIR)/30-bindings.yaml --ignore-not-found=true 2>/dev/null || true
	@$(KUBECTL) delete -f $(MANIFEST_DIR)/20-clusterroles.yaml --ignore-not-found=true 2>/dev/null || true
	@$(KUBECTL) delete -f $(MANIFEST_DIR)/10-namespaces-and-users.yaml --ignore-not-found=true 2>/dev/null || true
	@echo "$(GREEN)✓$(NC) Full reset completed"

##@ Status
status: ## Показать состояние RBAC ресурсов
	@echo "=== Cluster Info ==="
	@$(KUBECTL) cluster-info | head -1
	@echo ""
	@echo "=== Namespaces ==="
	@$(KUBECTL) get namespaces sales tenant-services finance data 2>/dev/null || echo "Not found"
	@echo ""
	@echo "=== ServiceAccounts (sales) ==="
	@$(KUBECTL) get serviceaccounts -n sales 2>/dev/null || echo "Not found"
	@echo ""
	@echo "=== Roles (sales) ==="
	@$(KUBECTL) get roles -n sales 2>/dev/null || echo "Not found"
	@echo ""
	@echo "=== ClusterRoles ==="
	@$(KUBECTL) get clusterroles cluster-viewer 2>/dev/null || echo "Not found"

##@ Testing
test-all: test-developer test-devops test-sre test-viewer ## Запустить все тесты прав доступа

test-developer: ## Тест прав developer роли
	@echo "=== Testing Developer Role ==="
	@echo -n "$(GREEN)✓$(NC) Get pods in sales: "
	@$(KUBECTL) auth can-i get pods --as=system:serviceaccount:sales:developer-sales -n sales
	@echo -n "$(GREEN)✓$(NC) Exec into pods: "
	@$(KUBECTL) auth can-i create pods/exec --as=system:serviceaccount:sales:developer-sales -n sales
	@echo -n "$(RED)✗$(NC) Get secrets: "
	@$(KUBECTL) auth can-i get secrets --as=system:serviceaccount:sales:developer-sales -n sales
	@echo -n "$(RED)✗$(NC) Update deployments: "
	@$(KUBECTL) auth can-i update deployment --as=system:serviceaccount:sales:developer-sales -n sales
	@echo -n "$(RED)✗$(NC) Access finance namespace: "
	@$(KUBECTL) auth can-i get pods --as=system:serviceaccount:sales:developer-sales -n finance
	@echo ""

test-devops: ## Тест прав DevOps роли
	@echo "=== Testing DevOps Role ==="
	@echo -n "$(GREEN)✓$(NC) Create deployments in sales: "
	@$(KUBECTL) auth can-i create deployment --as=system:serviceaccount:sales:devops-sales -n sales
	@echo -n "$(GREEN)✓$(NC) Get secrets in sales: "
	@$(KUBECTL) auth can-i get secrets --as=system:serviceaccount:sales:devops-sales -n sales
	@echo -n "$(RED)✗$(NC) Create deployments in finance: "
	@$(KUBECTL) auth can-i create deployment --as=system:serviceaccount:sales:devops-sales -n finance
	@echo ""

test-sre: ## Тест прав SRE роли
	@echo "=== Testing SRE Role ==="
	@echo -n "$(GREEN)✓$(NC) Get secrets: "
	@$(KUBECTL) auth can-i get secrets --as=system:serviceaccount:sales:sre-sales -n sales
	@echo -n "$(GREEN)✓$(NC) Patch deployments: "
	@$(KUBECTL) auth can-i patch deployment --as=system:serviceaccount:sales:sre-sales -n sales
	@echo -n "$(RED)✗$(NC) Delete deployments: "
	@$(KUBECTL) auth can-i delete deployment --as=system:serviceaccount:sales:sre-sales -n sales
	@echo ""

test-viewer: ## Тест прав viewer роли
	@echo "=== Testing Viewer Role ==="
	@echo -n "$(GREEN)✓$(NC) Get pods: "
	@$(KUBECTL) auth can-i get pods --as=system:serviceaccount:default:business-viewer -n sales
	@echo -n "$(RED)✗$(NC) Delete pods: "
	@$(KUBECTL) auth can-i delete pods --as=system:serviceaccount:default:business-viewer -n sales
	@echo -n "$(RED)✗$(NC) Get secrets: "
	@$(KUBECTL) auth can-i get secrets --as=system:serviceaccount:default:business-viewer -n sales
	@echo ""

verify: ## Запустить скрипт проверки rbac
	@bash $(SCRIPT_DIR)/verify-rbac.sh

help: ## Показать эту справку
	@awk 'BEGIN {FS=":.*##"; OFS=""} \
		/^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0,5); next} \
		/^[a-zA-Z0-9_.-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
