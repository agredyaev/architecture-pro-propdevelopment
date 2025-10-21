.DEFAULT_GOAL := help
.PHONY: help setup simulate analyze copy-log clean status validate

KUBECTL ?= kubectl
LOCAL_AUDIT_LOG := audit.log
AUDIT_EXTRACT := audit-extract.json
NAMESPACE := secure-ops
SCRIPTS_DIR := scripts
GREEN := \033[0;32m
RED := \033[0;31m
YELLOW := \033[1;33m
NC := \033[0m

##@ Setup
setup: ## Настроить Kubernetes с аудитом (автоопределение типа кластера)
	@printf "%b\n" "$(YELLOW)Setting up Kubernetes with audit logging...$(NC)"
	@bash $(SCRIPTS_DIR)/setup-audit.sh
	@printf "%b\n" "$(GREEN)✓$(NC) Kubernetes configured with audit policy"

##@ Simulation
simulate: ## Запустить симуляцию инцидентов безопасности
	@printf "%b\n" "$(YELLOW)Running security incident simulation...$(NC)"
	@bash $(SCRIPTS_DIR)/simulate-incident.sh
	@printf "%b\n" "$(GREEN)✓$(NC) Simulation completed"

##@ Analysis
copy-log: ## Скопировать audit.log из Kubernetes (автоопределение типа кластера)
	@echo "Copying audit log from Kubernetes..."
	@bash $(SCRIPTS_DIR)/copy-audit-log.sh
	@printf "%b\n" "$(GREEN)✓$(NC) Audit log copied to $(LOCAL_AUDIT_LOG)"

analyze: copy-log ## Анализировать audit.log и создать отчёт
	@printf "%b\n" "$(YELLOW)Analyzing audit log...$(NC)"
	@$(SCRIPTS_DIR)/analyze-audit.py $(LOCAL_AUDIT_LOG) $(AUDIT_EXTRACT)
	@printf "%b\n" "$(GREEN)✓$(NC) Analysis complete, results in $(AUDIT_EXTRACT)"

##@ Status
status: ## Показать состояние ресурсов
	@echo "=== Namespace ==="
	@$(KUBECTL) get namespace $(NAMESPACE) 2>/dev/null || echo "$(RED)Not found$(NC)"
	@echo ""
	@echo "=== Pods ==="
	@$(KUBECTL) get pods -n $(NAMESPACE) 2>/dev/null || echo "$(RED)Not found$(NC)"
	@echo ""
	@echo "=== Service Accounts ==="
	@$(KUBECTL) get sa -n $(NAMESPACE) 2>/dev/null || echo "$(RED)Not found$(NC)"
	@echo ""
	@echo "=== RoleBindings ==="
	@$(KUBECTL) get rolebindings -n $(NAMESPACE) 2>/dev/null || echo "$(RED)Not found$(NC)"

##@ Cleanup
clean: ## Удалить созданные ресурсы и локальные файлы
	@printf "%b\n" "$(YELLOW)Cleaning up resources...$(NC)"
	@$(KUBECTL) delete namespace $(NAMESPACE) --ignore-not-found=true
	@rm -f $(LOCAL_AUDIT_LOG)
	@echo "$(GREEN)✓$(NC) Cleanup complete"

help: ## Показать эту справку
	@awk 'BEGIN {FS=":.*##"; OFS=""} \
		/^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0,5); next} \
		/^[a-zA-Z0-9_.-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
