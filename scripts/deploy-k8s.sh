#!/bin/bash

# Auth Service 배포 스크립트
# 사용법: ./deploy-k8s.sh [environment]
# 예시: ./deploy-k8s.sh local  (Docker Compose)
#       ./deploy-k8s.sh dev    (로컬 k3d 클러스터)
#       ./deploy-k8s.sh prod   (EC2 k3s 클러스터)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
K8S_DIR="${PROJECT_DIR}/k8s"

ENVIRONMENT=${1:-local}
IMAGE_NAME="auth-service"
IMAGE_TAG=${2:-latest}
NAMESPACE="commerce"

# GitHub credentials (필수)
GH_USER=${GH_USER:-""}
GH_TOKEN=${GH_TOKEN:-""}

# EC2 설정 (prod 환경용)
EC2_HOST=${EC2_HOST:-""}
EC2_USER=${EC2_USER:-"ubuntu"}
EC2_KEY=${EC2_KEY:-"~/.ssh/id_rsa"}

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Auth Service Deployment${NC}"
echo -e "${GREEN}Environment: ${ENVIRONMENT}${NC}"
echo -e "${GREEN}Image: ${IMAGE_NAME}:${IMAGE_TAG}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 환경별 설정
case ${ENVIRONMENT} in
    local)
        echo -e "${YELLOW}[Local Mode]${NC} Using Docker Compose"
        echo ""

        # docker-compose 확인
        if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
            echo -e "${RED}Error: docker-compose not found${NC}"
            exit 1
        fi

        # GitHub credentials 확인
        if [ -z "$GH_USER" ] || [ -z "$GH_TOKEN" ]; then
            echo -e "${RED}Error: GitHub credentials not found${NC}"
            echo ""
            echo "GitHub Package Registry credentials are required for building the image."
            echo ""
            echo "Please set environment variables:"
            echo "  export GH_USER=your-github-username"
            echo "  export GH_TOKEN=your-github-token"
            echo ""
            exit 1
        fi

        echo -e "${YELLOW}Using GitHub credentials:${NC}"
        echo "  User: ${GH_USER}"
        echo "  Token: ${GH_TOKEN:0:4}****"
        echo ""

        # Docker 이미지 빌드
        echo "Building Docker image..."
        docker build \
          --build-arg GH_USER=${GH_USER} \
          --build-arg GH_TOKEN=${GH_TOKEN} \
          -t ${IMAGE_NAME}:${IMAGE_TAG} ${PROJECT_DIR}
        echo -e "${GREEN}✓${NC} Image built successfully"
        echo ""

        # Docker Compose로 실행
        echo "Starting services with Docker Compose..."
        if command -v docker-compose &> /dev/null; then
            docker-compose -f ${PROJECT_DIR}/docker-compose.yaml up -d
        else
            docker compose -f ${PROJECT_DIR}/docker-compose.yaml up -d
        fi
        echo -e "${GREEN}✓${NC} Services started"
        echo ""

        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}Deployment completed successfully!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo "Access application:"
        echo "  - MariaDB: localhost:3306"
        echo "  - App: Build and run the application locally"
        echo ""
        echo "Useful commands:"
        echo "  - View logs: docker-compose -f docker-compose.yaml logs -f"
        echo "  - Stop: docker-compose -f docker-compose.yaml down"
        echo "  - Restart: docker-compose -f docker-compose.yaml restart"
        echo ""
        exit 0
        ;;

    dev)
        echo -e "${YELLOW}[Dev Mode]${NC} Using local k3d cluster"
        echo ""

        # kubectl 확인
        if ! command -v kubectl &> /dev/null; then
            echo -e "${RED}Error: kubectl not found${NC}"
            exit 1
        fi

        # k3d 확인
        if ! command -v k3d &> /dev/null; then
            echo -e "${RED}Error: k3d not found${NC}"
            echo "Please install k3d: https://k3d.io"
            exit 1
        fi

        # GitHub credentials 확인
        if [ -z "$GH_USER" ] || [ -z "$GH_TOKEN" ]; then
            echo -e "${RED}Error: GitHub credentials not found${NC}"
            echo ""
            echo "Please set environment variables:"
            echo "  export GH_USER=your-github-username"
            echo "  export GH_TOKEN=your-github-token"
            echo ""
            exit 1
        fi

        echo -e "${YELLOW}Using GitHub credentials:${NC}"
        echo "  User: ${GH_USER}"
        echo "  Token: ${GH_TOKEN:0:4}****"
        echo ""

        # 현재 context 확인
        CURRENT_CONTEXT=$(kubectl config current-context)
        if [[ ! $CURRENT_CONTEXT == k3d-* ]]; then
            echo -e "${RED}Error: Current context is not k3d${NC}"
            echo "Current context: ${CURRENT_CONTEXT}"
            echo ""
            echo "Available k3d clusters:"
            k3d cluster list
            echo ""
            echo "Switch context using:"
            echo "  kubectl config use-context k3d-<cluster-name>"
            exit 1
        fi

        CLUSTER_NAME=${CURRENT_CONTEXT#k3d-}
        echo "Target k3d cluster: ${CLUSTER_NAME}"
        echo ""

        # Docker 이미지 빌드
        echo "Building Docker image..."
        docker build \
          --build-arg GH_USER=${GH_USER} \
          --build-arg GH_TOKEN=${GH_TOKEN} \
          -t ${IMAGE_NAME}:${IMAGE_TAG} ${PROJECT_DIR}
        echo -e "${GREEN}✓${NC} Image built successfully"
        echo ""

        # k3d로 이미지 import
        echo "Importing image to k3d cluster..."
        k3d image import ${IMAGE_NAME}:${IMAGE_TAG} -c ${CLUSTER_NAME}
        echo -e "${GREEN}✓${NC} Image imported to k3d cluster: ${CLUSTER_NAME}"
        echo ""
        ;;

    prod)
        echo -e "${YELLOW}[Prod Mode]${NC} Using EC2 k3s cluster"
        echo ""

        # kubectl 확인
        if ! command -v kubectl &> /dev/null; then
            echo -e "${RED}Error: kubectl not found${NC}"
            exit 1
        fi

        # EC2 설정 확인
        if [ -z "$EC2_HOST" ]; then
            echo -e "${RED}Error: EC2_HOST not set${NC}"
            echo ""
            echo "Please set EC2 connection information:"
            echo "  export EC2_HOST=ec2-instance-ip-or-hostname"
            echo "  export EC2_USER=ubuntu  # optional, default: ubuntu"
            echo "  export EC2_KEY=~/.ssh/id_rsa  # optional, default: ~/.ssh/id_rsa"
            echo ""
            exit 1
        fi

        # GitHub credentials 확인
        if [ -z "$GH_USER" ] || [ -z "$GH_TOKEN" ]; then
            echo -e "${RED}Error: GitHub credentials not found${NC}"
            echo ""
            echo "Please set environment variables:"
            echo "  export GH_USER=your-github-username"
            echo "  export GH_TOKEN=your-github-token"
            echo ""
            exit 1
        fi

        echo -e "${YELLOW}Using GitHub credentials:${NC}"
        echo "  User: ${GH_USER}"
        echo "  Token: ${GH_TOKEN:0:4}****"
        echo ""

        echo -e "${YELLOW}EC2 connection:${NC}"
        echo "  Host: ${EC2_HOST}"
        echo "  User: ${EC2_USER}"
        echo "  Key: ${EC2_KEY}"
        echo ""

        # SSH 연결 테스트
        echo "Testing SSH connection..."
        if ! ssh -i ${EC2_KEY} -o ConnectTimeout=5 -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} "echo 'SSH connection successful'" > /dev/null 2>&1; then
            echo -e "${RED}Error: Cannot connect to EC2 instance${NC}"
            echo "Please check your EC2_HOST, EC2_USER, and EC2_KEY settings"
            exit 1
        fi
        echo -e "${GREEN}✓${NC} SSH connection successful"
        echo ""

        # Docker 이미지 빌드
        echo "Building Docker image..."
        docker build \
          --build-arg GH_USER=${GH_USER} \
          --build-arg GH_TOKEN=${GH_TOKEN} \
          -t ${IMAGE_NAME}:${IMAGE_TAG} ${PROJECT_DIR}
        echo -e "${GREEN}✓${NC} Image built successfully"
        echo ""

        # 이미지를 tar로 저장
        echo "Saving image to tar file..."
        IMAGE_TAR="/tmp/${IMAGE_NAME}-${IMAGE_TAG}.tar"
        docker save ${IMAGE_NAME}:${IMAGE_TAG} -o ${IMAGE_TAR}
        echo -e "${GREEN}✓${NC} Image saved to ${IMAGE_TAR}"
        echo ""

        # EC2로 이미지 전송
        echo "Transferring image to EC2..."
        scp -i ${EC2_KEY} -o StrictHostKeyChecking=no ${IMAGE_TAR} ${EC2_USER}@${EC2_HOST}:/tmp/
        echo -e "${GREEN}✓${NC} Image transferred to EC2"
        echo ""

        # EC2에서 이미지 import
        echo "Importing image to k3s on EC2..."
        ssh -i ${EC2_KEY} -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} \
          "sudo k3s ctr images import /tmp/${IMAGE_NAME}-${IMAGE_TAG}.tar && rm /tmp/${IMAGE_NAME}-${IMAGE_TAG}.tar"
        echo -e "${GREEN}✓${NC} Image imported to k3s"
        echo ""

        # 로컬 tar 파일 삭제
        rm ${IMAGE_TAR}
        echo -e "${GREEN}✓${NC} Local tar file cleaned up"
        echo ""
        ;;

    *)
        echo -e "${RED}Unknown environment: ${ENVIRONMENT}${NC}"
        echo "Usage: $0 [local|dev|prod] [image-tag]"
        exit 1
        ;;
esac

echo ""

# 1. Namespace 확인
echo -e "${GREEN}[1/7]${NC} Checking namespace..."

if kubectl get namespace ${NAMESPACE} &> /dev/null; then
    echo -e "${GREEN}✓${NC} Namespace '${NAMESPACE}' exists"
else
    echo -e "${RED}✗ Namespace '${NAMESPACE}' does NOT exist${NC}"
    echo -e "${YELLOW}Please create the namespace via the INFRA repository before deploying.${NC}"
    echo ""
    echo "Example (in infra repo):"
    echo "  kubectl apply -f infra/k8s/namespaces/commerce.yaml"
    echo ""
    exit 1
fi
echo ""


# 2. MariaDB 배포
echo -e "${GREEN}[2/7]${NC} Deploying MariaDB..."
kubectl apply -f ${K8S_DIR}/mariadb-deployment.yaml
echo "Waiting for MariaDB to be ready..."
kubectl wait --for=condition=ready pod -l app=auth-service-mariadb -n ${NAMESPACE} --timeout=300s
echo -e "${GREEN}✓${NC} MariaDB is ready"
echo ""

# 3. ConfigMap 적용
echo -e "${GREEN}[3/7]${NC} Applying ConfigMap..."
kubectl apply -f ${K8S_DIR}/configmap.yaml
echo -e "${GREEN}✓${NC} ConfigMap applied"
echo ""

# 4. Secret 적용
echo -e "${GREEN}[4/7]${NC} Applying Secret..."
kubectl apply -f ${K8S_DIR}/secret.yaml
echo -e "${GREEN}✓${NC} Secret applied"
echo ""

# 5. Deployment 적용
echo -e "${GREEN}[5/7]${NC} Deploying application..."
kubectl apply -f ${K8S_DIR}/deployment.yaml
kubectl apply -f ${K8S_DIR}/service.yaml
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/auth-service -n ${NAMESPACE}
echo -e "${GREEN}✓${NC} Application deployed"
echo ""

# 6. HPA & PDB 적용
echo -e "${GREEN}[6/7]${NC} Configuring auto-scaling..."
kubectl apply -f ${K8S_DIR}/hpa.yaml
kubectl apply -f ${K8S_DIR}/pdb.yaml
echo -e "${GREEN}✓${NC} Auto-scaling configured"
echo ""

# 7. 배포 확인
echo -e "${GREEN}[7/7]${NC} Verifying deployment..."
echo ""

# Pods
echo "Pods:"
kubectl get pods -n ${NAMESPACE} -l app=auth-service

echo ""

# Services
echo "Services:"
kubectl get svc -n ${NAMESPACE} -l app=auth-service

echo ""

# HPA
echo "HPA:"
kubectl get hpa -n ${NAMESPACE}

echo ""

# Health check
echo "Checking application health..."
POD_NAME=$(kubectl get pod -n ${NAMESPACE} -l app=auth-service -o jsonpath='{.items[0].metadata.name}')

if [ -n "$POD_NAME" ]; then
    echo -n "Liveness: "
    if kubectl exec ${POD_NAME} -n ${NAMESPACE} -- \
        wget -qO- http://localhost:8080/actuator/health/liveness > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
    else
        echo -e "${YELLOW}⚠ Check manually${NC}"
    fi

    echo -n "Readiness: "
    if kubectl exec ${POD_NAME} -n ${NAMESPACE} -- \
        wget -qO- http://localhost:8080/actuator/health/readiness > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
    else
        echo -e "${YELLOW}⚠ Check manually${NC}"
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Useful commands:"
echo "  - View logs: kubectl logs -f deployment/auth-service -n ${NAMESPACE}"
echo "  - Port forward: kubectl port-forward svc/auth-service 8080:80 -n ${NAMESPACE}"
echo "  - Get pods: kubectl get pods -n ${NAMESPACE}"
echo "  - Describe pod: kubectl describe pod <pod-name> -n ${NAMESPACE}"
echo ""
echo "Access application:"
echo "  - kubectl port-forward svc/auth-service 8080:80 -n ${NAMESPACE}"
echo "  - Then open: http://localhost:8080/swagger-ui.html"
echo ""
