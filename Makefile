.PHONY: help jar build test clean docker-build docker-clean \
        gradle-build gradle-test gradle-clean \
        deploy-local deploy-dev deploy-prod validate \
        k8s-status k8s-describe k8s-stop k8s-start k8s-scale k8s-clean \
        flyway-history flyway-history-local flyway-clean flyway-clean-local flyway-reset flyway-reset-local

# Default target
.DEFAULT_GOAL := help

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RED    := \033[0;31m
NC     := \033[0m

help: ## Show this help message
	@echo "$(GREEN)Auth Service - Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Environment Variables:$(NC)"
	@echo "  GH_USER    - GitHub username (required for build)"
	@echo "  GH_TOKEN   - GitHub token (required for build)"
	@echo ""

# ============================================
# Local Development
# ============================================

test: ## Build and test locally with Docker
	@./scripts/test-local.sh

clean: ## Clean up local containers and data
	@echo "$(YELLOW)Cleaning up local environment...$(NC)"
	@docker rm -f auth-service-test 2>/dev/null || true
	@docker-compose down -v
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

jar: ## Build jar file with Gradle
	@echo "$(YELLOW)Building jar file...$(NC)"
	@./gradlew bootJar
	@echo "$(GREEN)✓ Jar file built$(NC)"

build: jar ## Build jar and Docker image
	@echo "$(YELLOW)Building Docker image...$(NC)"
	@docker build -t auth-service:latest .
	@echo "$(GREEN)✓ Image built: auth-service:latest$(NC)"

docker-build: build ## Alias for build (deprecated, use 'make build')

docker-clean: ## Remove Docker image
	@docker rmi auth-service:latest 2>/dev/null || true
	@echo "$(GREEN)✓ Docker image removed$(NC)"

# ============================================
# Gradle
# ============================================

gradle-build: ## Build with Gradle
	@./gradlew clean build

gradle-test: ## Run Gradle tests
	@./gradlew test

gradle-clean: ## Clean Gradle build
	@./gradlew clean

# ============================================
# Kubernetes Deployment
# ============================================

deploy-local: ## Deploy to local Kubernetes (Minikube/Kind)
	@./scripts/deploy-k8s.sh local

deploy-dev: ## Deploy to dev environment
	@./scripts/deploy-k8s.sh dev

deploy-prod: ## Deploy to prod environment
	@./scripts/deploy-k8s.sh prod

validate: ## Validate Kubernetes configurations
	@./scripts/validate.sh

# ============================================
# Kubernetes Management
# ============================================

k8s-status: ## Show Kubernetes resources status
	@echo "$(GREEN)Application Pods:$(NC)"
	@kubectl get pods -n commerce -l app=auth-service
	@echo ""
	@echo "$(GREEN)MariaDB Pods:$(NC)"
	@kubectl get pods -n commerce -l app=auth-service-mariadb
	@echo ""
	@echo "$(GREEN)Services:$(NC)"
	@kubectl get svc -n commerce -l service=auth-service
	@echo ""
	@echo "$(GREEN)HPA:$(NC)"
	@kubectl get hpa -n commerce -l app=auth-service
	@echo ""
	@echo "$(GREEN)Application Deployments:$(NC)"
	@kubectl get deployments -n commerce -l app=auth-service
	@echo ""
	@echo "$(GREEN)MariaDB Deployments:$(NC)"
	@kubectl get deployments -n commerce -l app=auth-service-mariadb
	@echo ""
	@echo "$(GREEN)PVC (Persistent Volume Claims):$(NC)"
	@kubectl get pvc -n commerce -l app=auth-service-mariadb

k8s-describe: ## Describe pod (for debugging)
	@kubectl describe pod -n commerce -l app=auth-service

k8s-stop: ## Stop application (scale to 0)
	@echo "$(YELLOW)Stopping application (scaling to 0)...$(NC)"
	@kubectl scale deployment/auth-service -n commerce --replicas=0
	@kubectl scale deployment/auth-service-mariadb -n commerce --replicas=0
	@echo "$(GREEN)✓ Application stopped (replicas=0)$(NC)"

k8s-start: ## Start application (scale to 2)
	@echo "$(YELLOW)Starting application (scaling to 2)...$(NC)"
	@kubectl scale deployment/auth-service -n commerce --replicas=2
	@kubectl scale deployment/auth-service-mariadb -n commerce --replicas=1
	@echo "$(GREEN)✓ Application started (replicas=2)$(NC)"

k8s-scale: ## Scale application (usage: make k8s-scale REPLICAS=3)
	@if [ -z "$(REPLICAS)" ]; then \
		echo "$(RED)Error: REPLICAS not specified$(NC)"; \
		echo "Usage: make k8s-scale REPLICAS=3"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Scaling application to $(REPLICAS) replicas...$(NC)"
	@kubectl scale deployment/auth-service -n commerce --replicas=$(REPLICAS)
	@echo "$(GREEN)✓ Application scaled to $(REPLICAS) replicas$(NC)"

k8s-clean: ## Delete all Kubernetes resources
	@echo "$(YELLOW)Deleting all resources from commerce namespace...$(NC)"
	@kubectl delete deployment,svc,configmap,secret,hpa,pdb -n commerce -l app=auth-service 2>/dev/null || true
	@kubectl delete deployment,svc,secret,pvc -n commerce -l app=auth-service-mariadb 2>/dev/null || true
	@echo "$(GREEN)✓ Resources deleted$(NC)"

# ============================================
# Flyway Management
# ============================================

flyway-history: ## Show Flyway migration history (K8s)
	@echo "$(GREEN)Flyway Migration History:$(NC)"
	@kubectl exec deployment/auth-service-mariadb -n commerce -- \
		mariadb -uadmin -padmin1234 commerce-auth \
		-e "SELECT installed_rank, version, description, type, installed_on, execution_time, success FROM flyway_schema_history;" \
		2>/dev/null || echo "$(RED)Error: Cannot connect to MariaDB$(NC)"

flyway-history-local: ## Show Flyway migration history (Local)
	@echo "$(GREEN)Flyway Migration History:$(NC)"
	@docker exec auth-mariadb mariadb -uadmin -padmin1234 commerce-auth \
		-e "SELECT installed_rank, version, description, type, installed_on, execution_time, success FROM flyway_schema_history;" \
		2>/dev/null || echo "$(RED)Error: Cannot connect to local MariaDB$(NC)"

flyway-clean: ## Clean failed Flyway migrations (K8s)
	@echo "$(YELLOW)Cleaning failed Flyway migrations...$(NC)"
	@kubectl exec deployment/auth-service-mariadb -n commerce -- \
		mariadb -uadmin -padmin1234 commerce-auth \
		-e "DELETE FROM flyway_schema_history WHERE success = 0;" \
		2>/dev/null && echo "$(GREEN)✓ Failed migrations removed$(NC)" \
		|| echo "$(RED)Error: Cannot clean migrations$(NC)"

flyway-clean-local: ## Clean failed Flyway migrations (Local)
	@echo "$(YELLOW)Cleaning failed Flyway migrations...$(NC)"
	@docker exec auth-mariadb mariadb -uadmin -padmin1234 commerce-auth \
		-e "DELETE FROM flyway_schema_history WHERE success = 0;" \
		2>/dev/null && echo "$(GREEN)✓ Failed migrations removed$(NC)" \
		|| echo "$(RED)Error: Cannot clean migrations$(NC)"

flyway-reset: ## Reset Flyway history completely (K8s) - DANGEROUS!
	@echo "$(RED)WARNING: This will delete ALL Flyway history!$(NC)"
	@echo "$(YELLOW)Press Ctrl+C to cancel, or Enter to continue...$(NC)"
	@read confirm
	@kubectl exec deployment/auth-service-mariadb -n commerce -- \
		mariadb -uadmin -padmin1234 commerce-auth \
		-e "DROP TABLE IF EXISTS flyway_schema_history;" \
		2>/dev/null && echo "$(GREEN)✓ Flyway history reset$(NC)" \
		|| echo "$(RED)Error: Cannot reset Flyway$(NC)"

flyway-reset-local: ## Reset Flyway history completely (Local) - DANGEROUS!
	@echo "$(RED)WARNING: This will delete ALL Flyway history!$(NC)"
	@echo "$(YELLOW)Press Ctrl+C to cancel, or Enter to continue...$(NC)"
	@read confirm
	@docker exec auth-mariadb mariadb -uadmin -padmin1234 commerce-auth \
		-e "DROP TABLE IF EXISTS flyway_schema_history;" \
		2>/dev/null && echo "$(GREEN)✓ Flyway history reset$(NC)" \
		|| echo "$(RED)Error: Cannot reset Flyway$(NC)"
