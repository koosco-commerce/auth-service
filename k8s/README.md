# Kubernetes Deployment Guide for Auth Service

## Overview
Complete Kubernetes configuration for the auth-service microservice with MariaDB database.

## Architecture
```
┌─────────────────┐
│    Ingress      │
│ (auth.example)  │
└────────┬────────┘
         │
┌────────▼────────┐
│  Auth Service   │
│   (2-10 pods)   │
└────────┬────────┘
         │
┌────────▼────────┐
│    MariaDB      │
│   (1 replica)   │
└─────────────────┘
```

## Prerequisites
- Kubernetes cluster (v1.19+)
- kubectl configured
- Nginx Ingress Controller (for ingress)
- Metrics Server (for HPA)

## Files Structure
```
k8s/
├── namespace.yaml              # Commerce namespace
├── configmap.yaml             # Application configuration
├── secret.yaml                # Sensitive data (JWT, DB password)
├── deployment.yaml            # Auth service deployment
├── service.yaml              # Service definitions
├── mariadb-deployment.yaml   # Database deployment
├── ingress.yaml              # Ingress rules
├── hpa.yaml                  # Horizontal Pod Autoscaler
├── pdb.yaml                  # Pod Disruption Budget
└── README.md                 # This file
```

## Quick Start

### 1. Create Namespace
```bash
kubectl apply -f k8s/namespace.yaml
```

### 2. Configure Secrets
**⚠️ IMPORTANT**: Update secrets before deploying to production!

Edit `k8s/secret.yaml` and update:
- `DB_PASSWORD`: Your database password
- `JWT_SECRET`: Your JWT signing secret (min 256 bits)
- `GH_USER` & `GH_TOKEN`: GitHub credentials for private dependencies

```bash
kubectl apply -f k8s/secret.yaml
```

### 3. Deploy Database
```bash
kubectl apply -f k8s/mariadb-deployment.yaml
```

Wait for MariaDB to be ready:
```bash
kubectl wait --for=condition=ready pod -l app=mariadb -n commerce --timeout=300s
```

### 4. Deploy Application
```bash
# Apply ConfigMap
kubectl apply -f k8s/configmap.yaml

# Deploy application
kubectl apply -f k8s/deployment.yaml

# Create services
kubectl apply -f k8s/service.yaml
```

### 5. Configure Auto-scaling
```bash
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/pdb.yaml
```

### 6. Setup Ingress (Optional)
Update `k8s/ingress.yaml` with your domain and apply:
```bash
kubectl apply -f k8s/ingress.yaml
```

## Deploy All at Once
```bash
kubectl apply -f k8s/
```

## Verification

### Check Deployment Status
```bash
kubectl get all -n commerce
```

### Check Pods
```bash
kubectl get pods -n commerce
kubectl logs -f deployment/auth-service -n commerce
```

### Check Services
```bash
kubectl get svc -n commerce
```

### Check HPA Status
```bash
kubectl get hpa -n commerce
```

### Test Database Connection
```bash
kubectl exec -it deployment/mariadb -n commerce -- mysql -uadmin -padmin1234 -e "SHOW DATABASES;"
```

## Configuration

### Environment Variables
Main configuration is in `configmap.yaml`. Key settings:

- **SPRING_PROFILES_ACTIVE**: `dev`, `prod`
- **DB_HOST**: Database service name
- **JWT_EXPIRATION**: Token expiration (seconds)

### Resource Limits
In `deployment.yaml`:
- **Requests**: memory=512Mi, cpu=250m
- **Limits**: memory=1Gi, cpu=1000m

Adjust based on your workload.

### Auto-scaling
In `hpa.yaml`:
- **Min replicas**: 2
- **Max replicas**: 10
- **Target CPU**: 70%
- **Target Memory**: 80%

## Health Checks

### Endpoints
- **Liveness**: `/actuator/health/liveness`
- **Readiness**: `/actuator/health/readiness`
- **Startup**: `/actuator/health/liveness`

### Probe Configuration
- **Startup**: 30 attempts × 10s = 5 min max startup time
- **Liveness**: Check every 10s, fail after 3 consecutive failures
- **Readiness**: Check every 5s, fail after 3 consecutive failures

## Database Management

### Persistent Storage
MariaDB uses a PersistentVolumeClaim (10Gi). Data persists across pod restarts.

### Backup Database
```bash
kubectl exec deployment/mariadb -n commerce -- \
  mysqldump -uroot -proot commerce-auth > backup.sql
```

### Restore Database
```bash
kubectl exec -i deployment/mariadb -n commerce -- \
  mysql -uroot -proot commerce-auth < backup.sql
```

### Access Database Shell
```bash
kubectl exec -it deployment/mariadb -n commerce -- \
  mysql -uadmin -padmin1234 commerce-auth
```

## Updating the Application

### Rolling Update
```bash
# Update image in deployment.yaml, then:
kubectl apply -f k8s/deployment.yaml

# Or update image directly:
kubectl set image deployment/auth-service \
  auth-service=auth-service:v2.0.0 -n commerce

# Watch rollout status:
kubectl rollout status deployment/auth-service -n commerce
```

### Rollback
```bash
kubectl rollout undo deployment/auth-service -n commerce

# Rollback to specific revision:
kubectl rollout undo deployment/auth-service -n commerce --to-revision=2
```

## Troubleshooting

### Pod Not Starting
```bash
kubectl describe pod <pod-name> -n commerce
kubectl logs <pod-name> -n commerce
```

### Database Connection Issues
```bash
# Check database service
kubectl get svc mariadb-service -n commerce

# Test connection from auth-service pod
kubectl exec -it deployment/auth-service -n commerce -- \
  nc -zv mariadb-service 3306
```

### View Application Logs
```bash
# Recent logs
kubectl logs deployment/auth-service -n commerce --tail=100

# Follow logs
kubectl logs -f deployment/auth-service -n commerce

# Logs from all replicas
kubectl logs -l app=auth-service -n commerce
```

### Check Resource Usage
```bash
kubectl top pods -n commerce
kubectl top nodes
```

### Debug Pod
```bash
kubectl exec -it deployment/auth-service -n commerce -- /bin/sh
```

## Security Best Practices

### 1. Secrets Management
- ✅ Use external secret managers (Vault, AWS Secrets Manager)
- ✅ Rotate secrets regularly
- ✅ Never commit secrets to git
- ✅ Use RBAC to limit secret access

### 2. Network Policies
Consider adding NetworkPolicy to restrict pod communication:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: auth-service-netpol
  namespace: commerce
spec:
  podSelector:
    matchLabels:
      app: auth-service
  policyTypes:
    - Ingress
    - Egress
```

### 3. Pod Security
- ✅ Run as non-root user
- ✅ Use read-only root filesystem
- ✅ Drop unnecessary capabilities
- ✅ Use security contexts

### 4. Image Security
- ✅ Use specific image tags (not `latest`)
- ✅ Scan images for vulnerabilities
- ✅ Use private registry
- ✅ Sign images

## Monitoring & Observability

### Prometheus Integration
Add annotations to service for Prometheus scraping:
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/actuator/prometheus"
```

### Logging
Spring Boot logs are sent to stdout/stderr and collected by Kubernetes.

### Metrics
Access metrics at `/actuator/metrics` endpoint.

## Production Considerations

### 1. Resource Planning
- Monitor actual resource usage
- Adjust requests/limits based on metrics
- Plan for peak load

### 2. High Availability
- Run multiple replicas (min 2)
- Use PodDisruptionBudget
- Distribute across availability zones

### 3. Backup Strategy
- Automated database backups
- Test restore procedures
- Store backups off-cluster

### 4. Disaster Recovery
- Document recovery procedures
- Practice failover scenarios
- Maintain configuration backups

## Clean Up

### Delete All Resources
```bash
kubectl delete namespace commerce
```

### Delete Specific Resources
```bash
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/service.yaml
# etc...
```

## Additional Resources
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Spring Boot on Kubernetes](https://spring.io/guides/gs/spring-boot-kubernetes/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
