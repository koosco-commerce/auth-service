#!/bin/bash

# Auth Service 로컬 빌드 & 테스트 스크립트
# 사용법: ./test-local.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
IMAGE_NAME="auth-service"
IMAGE_TAG="latest"
CONTAINER_NAME="auth-service-test"

# GitHub credentials (필수)
GH_USER=${GH_USER:-""}
GH_TOKEN=${GH_TOKEN:-""}

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Auth Service Local Build & Test${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# GitHub credentials 확인
if [ -z "$GH_USER" ] || [ -z "$GH_TOKEN" ]; then
    echo -e "${RED}Error: GitHub credentials not found${NC}"
    echo ""
    echo "GitHub Package Registry credentials are required for private dependencies."
    echo ""
    echo "Please set environment variables:"
    echo "  export GH_USER=your-github-username"
    echo "  export GH_TOKEN=your-github-token"
    echo ""
    echo "Or pass them inline:"
    echo "  GH_USER=xxx GH_TOKEN=yyy ./test-local.sh"
    echo ""
    exit 1
fi

echo -e "${YELLOW}Using GitHub credentials:${NC}"
echo "  User: ${GH_USER}"
echo "  Token: ${GH_TOKEN:0:4}****"
echo ""

# 1. Gradle Build
echo -e "${GREEN}[1/6]${NC} Building with Gradle..."
cd "${PROJECT_DIR}"
./gradlew clean build -x test
echo -e "${GREEN}✓${NC} Gradle build complete"
echo ""

# 2. Docker Build
echo -e "${GREEN}[2/6]${NC} Building Docker image..."
docker build \
  --build-arg GH_USER=${GH_USER} \
  --build-arg GH_TOKEN=${GH_TOKEN} \
  -t ${IMAGE_NAME}:${IMAGE_TAG} "${PROJECT_DIR}"
echo -e "${GREEN}✓${NC} Docker image built: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

# 3. Start Database
echo -e "${GREEN}[3/6]${NC} Starting MariaDB..."
cd "${PROJECT_DIR}"
docker-compose up -d db
echo "Waiting for database to be ready..."
sleep 10
echo -e "${GREEN}✓${NC} Database is ready"
echo ""

# 4. Run Application Container
echo -e "${GREEN}[4/6]${NC} Starting auth-service container..."

# 기존 컨테이너 제거
docker rm -f ${CONTAINER_NAME} 2>/dev/null || true

# Docker Compose 네트워크에 연결하기 위한 네트워크 이름
NETWORK_NAME="${PROJECT_DIR##*/}_default"

# 컨테이너 실행
docker run -d \
  --name ${CONTAINER_NAME} \
  --network ${NETWORK_NAME} \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=local \
  -e DB_HOST=auth-mariadb \
  -e DB_PORT=3306 \
  -e DB_NAME=commerce-auth \
  -e DB_USERNAME=admin \
  -e DB_PASSWORD=admin1234 \
  -e JWT_SECRET=mySecretKeyForJWTWhichShouldBeAtLeast256BitsLongToEnsureSecurityAndCompliance \
  -e JWT_EXPIRATION=86400 \
  -e JWT_REFRESH_EXPIRATION=604800 \
  ${IMAGE_NAME}:${IMAGE_TAG}

echo "Waiting for application to start..."
sleep 15
echo -e "${GREEN}✓${NC} Application container started"
echo ""

# 5. Health Check
echo -e "${GREEN}[5/6]${NC} Running health checks..."

# Liveness check
echo -n "Liveness: "
if curl -f -s http://localhost:8080/actuator/health/liveness > /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    docker logs ${CONTAINER_NAME}
    exit 1
fi

# Readiness check
echo -n "Readiness: "
if curl -f -s http://localhost:8080/actuator/health/readiness > /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    docker logs ${CONTAINER_NAME}
    exit 1
fi

# Health check
echo -n "Health: "
if curl -f -s http://localhost:8080/actuator/health > /dev/null; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    docker logs ${CONTAINER_NAME}
    exit 1
fi

echo ""

# 6. Show Information
echo -e "${GREEN}[6/6]${NC} Test Results"
echo -e "${GREEN}========================================${NC}"
echo -e "✅ Build: ${GREEN}SUCCESS${NC}"
echo -e "✅ Database: ${GREEN}RUNNING${NC}"
echo -e "✅ Application: ${GREEN}RUNNING${NC}"
echo -e "✅ Health Checks: ${GREEN}PASSED${NC}"
echo ""
echo "Application URLs:"
echo "  - Health: http://localhost:8080/actuator/health"
echo "  - Swagger: http://localhost:8080/swagger-ui.html"
echo "  - API Docs: http://localhost:8080/v3/api-docs"
echo ""
echo "Container Info:"
echo "  - Name: ${CONTAINER_NAME}"
echo "  - Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "Useful commands:"
echo "  - View logs: docker logs -f ${CONTAINER_NAME}"
echo "  - Stop: docker stop ${CONTAINER_NAME}"
echo "  - Remove: docker rm ${CONTAINER_NAME}"
echo "  - Cleanup all: docker-compose down && docker rm -f ${CONTAINER_NAME}"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
