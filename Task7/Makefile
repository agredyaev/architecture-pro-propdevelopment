.DEFAULT_GOAL := help
.PHONY: help setup namespace gatekeeper-templates gatekeeper-constraints gatekeeper verify-admission validate-security apply-secure delete-secure status clean

KUBECTL ?= kubectl
NAMESPACE ?= audit-zone
ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SECURE_MANIFESTS := $(ROOT_DIR)/secure-manifests
VERIFY_DIR := $(ROOT_DIR)/verify

GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

##@ Bootstrap
namespace: ## Создать namespace с уровнем PodSecurity restricted
	@echo "$(YELLOW)Applying namespace $(NAMESPACE)...$(NC)"
	@$(KUBECTL) apply -f $(ROOT_DIR)/01-create-namespace.yaml >/dev/null
	@echo "$(GREEN)✓$(NC) Namespace $(NAMESPACE) готов"

gatekeeper-templates: ## Применить Gatekeeper ConstraintTemplates
	@echo "$(YELLOW)Applying Gatekeeper constraint templates...$(NC)"
	@$(KUBECTL) apply -f $(ROOT_DIR)/gatekeeper/constraint-templates/ >/dev/null
	@echo "$(GREEN)✓$(NC) ConstraintTemplates применены"

gatekeeper-constraints: gatekeeper-templates ## Применить Gatekeeper Constraints
	@echo "$(YELLOW)Applying Gatekeeper constraints...$(NC)"
	@$(KUBECTL) apply -f $(ROOT_DIR)/gatekeeper/constraints/ >/dev/null
	@echo "$(GREEN)✓$(NC) Constraints применены"

gatekeeper: namespace gatekeeper-constraints ## Настроить namespace и политики Gatekeeper
	@echo "$(GREEN)✓$(NC) Namespace и политики безопасности готовы"

setup: gatekeeper ## Полностью подготовить среду (namespace + Gatekeeper)
	@true

##@ Verification
verify-admission: ## Запустить комплексную проверку admission-контроля
	@bash $(VERIFY_DIR)/verify-admission.sh

validate-security: ## Провести аудит запущенных подов на соответствие политике
	@bash $(VERIFY_DIR)/validate-security.sh

apply-secure: namespace ## Развернуть безопасные примеры подов
	@echo "$(YELLOW)Deploying secure sample pods...$(NC)"
	@$(KUBECTL) apply -f $(SECURE_MANIFESTS)/ >/dev/null
	@echo "$(GREEN)✓$(NC) Безопасные поды развернуты"

delete-secure: ## Удалить безопасные пример pod'ы
	@echo "$(YELLOW)Removing secure sample pods...$(NC)"
	@$(KUBECTL) delete -f $(SECURE_MANIFESTS)/ --ignore-not-found >/dev/null || true
	@echo "$(GREEN)✓$(NC) Примеры подов удалены"

status: ## Показать состояние ресурсов в namespace audit-zone
	@echo "=== Namespace ==="
	@$(KUBECTL) get namespace $(NAMESPACE) 2>/dev/null || echo "$(RED)Not found$(NC)"
	@printf '\n=== Pods ===\n'
	@$(KUBECTL) get pods -n $(NAMESPACE) 2>/dev/null || echo "$(RED)Not found$(NC)"

##@ Cleanup
clean: delete-secure ## Удалить namespace audit-zone и примеры подов
	@echo "$(YELLOW)Deleting namespace $(NAMESPACE)...$(NC)"
	@$(KUBECTL) delete namespace $(NAMESPACE) --ignore-not-found >/dev/null || true
	@echo "$(GREEN)✓$(NC) Очистка завершена"

help: ## Показать справку по доступным целям
	@awk 'BEGIN {FS=":.*##"; OFS=""} \
		/^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0,5); next} \
		/^[a-zA-Z0-9_.-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
