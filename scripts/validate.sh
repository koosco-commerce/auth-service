#!/bin/bash

# Kubernetes Configuration Validator
# Validates YAML files for syntax and common issues

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
K8S_DIR="${PROJECT_DIR}/k8s"
ERRORS=0

echo "========================================="
echo "Kubernetes Configuration Validator"
echo "========================================="
echo ""

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}[✗]${NC} kubectl is not installed"
    exit 1
fi

echo -e "${GREEN}[✓]${NC} kubectl is installed"

# Validate each YAML file
for file in "${K8S_DIR}"/*.yaml; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")

        # Skip kustomization.yaml (not a K8s resource)
        if [ "$filename" = "kustomization.yaml" ]; then
            echo -e "Skipping $filename... ${YELLOW}(Kustomize config)${NC}"
            continue
        fi

        echo -n "Validating $filename... "

        # Dry-run validation
        if kubectl apply -f "$file" --dry-run=client &> /dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            kubectl apply -f "$file" --dry-run=client 2>&1 | head -5
            ((ERRORS++))
        fi
    fi
done

echo ""
echo "========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All validations passed!${NC}"
    echo "========================================="
    exit 0
else
    echo -e "${RED}Found $ERRORS error(s)${NC}"
    echo "========================================="
    exit 1
fi
