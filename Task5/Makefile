.DEFAULT_GOAL := help
.PHONY: help status validate apply delete reset test

KUBECTL ?= kubectl
NAMESPACE := demo-network-policies
MANIFEST_DIR := manifests
SCRIPT_DIR := scripts
MANIFESTS := \
	$(MANIFEST_DIR)/10-namespace-and-services.yaml \
	$(MANIFEST_DIR)/20-default-deny.yaml \
	$(MANIFEST_DIR)/30-client-api-policy.yaml \
	$(MANIFEST_DIR)/40-admin-api-policy.yaml

GREEN := \033[0;32m
RED := \033[0;31m
YELLOW := \033[1;33m
NC := \033[0m

##@ Deployment
validate: ## Валидировать манифесты без применения
	@echo "Validating YAML manifests..."
	@for manifest in $(MANIFESTS); do \
		$(KUBECTL) apply -f $$manifest --dry-run=client >/dev/null && \
		echo " - validated $$manifest"; \
	done
	@echo "$(GREEN)✓$(NC) All manifests are valid"

apply: ## Применить Network Policies (deploy -> deny -> allow)
	@echo "Step 1/4: Creating namespace and deploying services..."
	@$(KUBECTL) apply -f $(MANIFEST_DIR)/10-namespace-and-services.yaml
	@echo "Waiting for pods to be ready..."
	@$(KUBECTL) wait --for=condition=ready pod --all -n $(NAMESPACE) --timeout=60s || true
	@echo "Step 2/4: Applying default deny policies..."
	@$(KUBECTL) apply -f $(MANIFEST_DIR)/20-default-deny.yaml
	@echo "Step 3/4: Applying client services policies..."
	@$(KUBECTL) apply -f $(MANIFEST_DIR)/30-client-api-policy.yaml
	@echo "Step 4/4: Applying admin services policies..."
	@$(KUBECTL) apply -f $(MANIFEST_DIR)/40-admin-api-policy.yaml
	@echo "$(GREEN)✓$(NC) Network Policies applied successfully"

delete: ## Удалить все ресурсы
	@echo "Deleting Network Policies and services..."
	@$(KUBECTL) delete -f $(MANIFEST_DIR)/40-admin-api-policy.yaml --ignore-not-found=true
	@$(KUBECTL) delete -f $(MANIFEST_DIR)/30-client-api-policy.yaml --ignore-not-found=true
	@$(KUBECTL) delete -f $(MANIFEST_DIR)/20-default-deny.yaml --ignore-not-found=true
	@$(KUBECTL) delete -f $(MANIFEST_DIR)/10-namespace-and-services.yaml --ignore-not-found=true
	@echo "$(GREEN)✓$(NC) Resources deleted"

reset: delete ## Полный сброс (alias для delete)

##@ Status
status: ## Показать состояние Network Policies
	@echo "=== Namespace ==="
	@$(KUBECTL) get namespace $(NAMESPACE) 2>/dev/null || echo "$(RED)Not found$(NC)"
	@echo ""
	@echo "=== Pods ==="
	@$(KUBECTL) get pods -n $(NAMESPACE) 2>/dev/null || echo "$(RED)Not found$(NC)"
	@echo ""
	@echo "=== Services ==="
	@$(KUBECTL) get services -n $(NAMESPACE) 2>/dev/null || echo "$(RED)Not found$(NC)"
	@echo ""
	@echo "=== Network Policies ==="
	@$(KUBECTL) get networkpolicies -n $(NAMESPACE) 2>/dev/null || echo "$(RED)Not found$(NC)"

##@ Testing
test: ## Запустить тесты Network Policies
	@echo "$(YELLOW)Running Network Policy tests...$(NC)"
	@bash $(SCRIPT_DIR)/test-network-policies.sh

help: ## Показать эту справку
	@awk 'BEGIN {FS=":.*##"; OFS=""} \
		/^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0,5); next} \
		/^[a-zA-Z0-9_.-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
