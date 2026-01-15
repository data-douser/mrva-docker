---
name: test-helm-chart-on-minikube
description: Skill for testing the deployment of `codeql-mrva-chart` helm chart on a local Minikube cluster.
---

# Skill `test-helm-chart-on-minikube`

## Prerequisites

- `minikube` installed and running (`minikube status` shows Running)
- `kubectl` configured to use minikube context
- `helm` CLI installed (v3.x)

## Quick Verification

```bash
# Verify minikube is running
minikube status

# Verify kubectl connectivity
kubectl cluster-info

# Lint the chart before deploying
helm lint k8s/codeql-mrva-chart
```

## Deployment Testing

### Full Deployment with Test Images

The custom container images (mrva-server, mrva-agent, mrva-hepc-container) may not be available locally. Use the provided test image script to create minimal Flask-based containers that respond to health checks:

```bash
# Build test images and load into minikube
./scripts/create-test-images.sh --load

# Verify images are loaded
minikube image ls | grep -E "mrva|hepc"
```

Deploy using the test-values.yaml override which disables commands/args that test images don't support:

```bash
helm install mrva k8s/codeql-mrva-chart \
  -f k8s/codeql-mrva-chart/test-values.yaml \
  --namespace mrva-test \
  --create-namespace \
  --wait --timeout 5m
```

### Full Deployment with Production Images

If production images are available:

```bash
# Load production images into minikube
minikube image load mrva-server:0.4.5
minikube image load mrva-agent:0.4.5
minikube image load mrva-hepc-container:0.4.5

# Install without test-values.yaml override
helm install mrva k8s/codeql-mrva-chart \
  --namespace mrva-test \
  --create-namespace \
  --wait --timeout 5m
```

### Infrastructure-Only Deployment (No Custom Images)

To test just the infrastructure services (postgres, minio, rabbitmq) without requiring custom images:

```bash
helm install mrva k8s/codeql-mrva-chart \
  --namespace mrva-test \
  --create-namespace \
  --set server.enabled=false \
  --set agent.enabled=false \
  --set hepc.enabled=false \
  --wait --timeout 3m
```

### Dry-Run First

Always perform a dry-run before actual installation:

```bash
helm install mrva k8s/codeql-mrva-chart \
  --namespace mrva-test \
  --create-namespace \
  --dry-run=client
```

## Validation Commands

### Check Deployment Status

```bash
# View all resources in the namespace
kubectl get all -n mrva-test

# Check helm release status
helm status mrva -n mrva-test

# View pods with labels
kubectl get pods -n mrva-test -l "app.kubernetes.io/instance=mrva"

# View services
kubectl get svc -n mrva-test -l "app.kubernetes.io/instance=mrva"

# Check persistent volume claims
kubectl get pvc -n mrva-test
```

### Check Pod Logs

```bash
# PostgreSQL logs
kubectl logs -n mrva-test statefulset/mrva-codeql-mrva-chart-postgres --tail=20

# RabbitMQ logs
kubectl logs -n mrva-test deployment/mrva-codeql-mrva-chart-rabbitmq --tail=20

# MinIO logs
kubectl logs -n mrva-test statefulset/mrva-codeql-mrva-chart-minio --tail=20

# MinIO init job logs (verify bucket creation)
kubectl logs -n mrva-test job/mrva-codeql-mrva-chart-minio-init
```

### Port-Forward for Local Access

```bash
# MinIO Console (http://localhost:9001)
kubectl port-forward -n mrva-test svc/mrva-codeql-mrva-chart-minio 9001:9001

# RabbitMQ Management (http://localhost:15672)
kubectl port-forward -n mrva-test svc/mrva-codeql-mrva-chart-rabbitmq 15672:15672

# PostgreSQL (localhost:5432)
kubectl port-forward -n mrva-test svc/mrva-codeql-mrva-chart-postgres 5432:5432
```

## Expected Results

### Successful Infrastructure Deployment

When deploying with infrastructure-only (server/agent/hepc disabled):

| Resource Type | Name | Expected Status |
|---------------|------|-----------------|
| StatefulSet | mrva-codeql-mrva-chart-postgres | 1/1 Ready |
| StatefulSet | mrva-codeql-mrva-chart-minio | 1/1 Ready |
| Deployment | mrva-codeql-mrva-chart-rabbitmq | 1/1 Ready |
| Job | mrva-codeql-mrva-chart-minio-init | Complete (1/1) |
| PVC | postgres-data-mrva-codeql-mrva-chart-postgres-0 | Bound |
| PVC | minio-data-mrva-codeql-mrva-chart-minio-0 | Bound |
| PVC | mrva-codeql-mrva-chart-rabbitmq-data | Bound |

### Key Log Indicators

- **PostgreSQL**: "database system is ready to accept connections"
- **RabbitMQ**: "Server startup complete; 5 plugins started"
- **MinIO Init**: "Bucket created successfully"

### Full Deployment Success (with Test Images)

When deploying with test images and test-values.yaml:

| Resource Type | Name | Expected Status |
|---------------|------|-----------------|
| Deployment | mrva-codeql-mrva-chart-server | 1/1 Ready |
| Deployment | mrva-codeql-mrva-chart-agent | 1/1 Ready |
| Deployment | mrva-codeql-mrva-chart-hepc | 1/1 Ready |
| StatefulSet | mrva-codeql-mrva-chart-postgres | 1/1 Ready |
| StatefulSet | mrva-codeql-mrva-chart-minio | 1/1 Ready |
| Deployment | mrva-codeql-mrva-chart-rabbitmq | 1/1 Ready |
| Job | mrva-codeql-mrva-chart-minio-init | Complete (1/1) |

### Verify Service Connectivity

```bash
# Test server health from agent pod
kubectl exec -n mrva-test deploy/mrva-codeql-mrva-chart-agent -- \
  wget -q -O- http://mrva-codeql-mrva-chart-server:8080/health

# Test HEPC health from agent pod
kubectl exec -n mrva-test deploy/mrva-codeql-mrva-chart-agent -- \
  wget -q -O- http://mrva-codeql-mrva-chart-hepc:8070/health
```

## Cleanup

```bash
# Uninstall the release
helm uninstall mrva -n mrva-test

# Delete the namespace (removes PVCs too)
kubectl delete namespace mrva-test
```

## Troubleshooting

### Pods Stuck in Pending

Check if PVCs are bound and minikube has sufficient storage:

```bash
kubectl get pvc -n mrva-test
kubectl describe pvc <pvc-name> -n mrva-test
minikube ssh -- df -h
```

### Image Pull Errors (ErrImagePull/ImagePullBackOff)

Custom images need to be loaded into minikube:

```bash
# Check if image exists in minikube
minikube image ls | grep mrva

# Load local image
minikube image load <image-name>:<tag>

# Or use minikube's docker daemon
eval $(minikube docker-env)
docker build -t mrva-server:0.4.5 ./containers/server/
```

### Container CrashLoopBackOff with "executable file not found"

This indicates the Helm chart is passing commands/args that the container doesn't understand. Common causes:

1. **Using test images without test-values.yaml**: Test images don't have production binaries
2. **Kubernetes `command` overrides ENTRYPOINT**: The chart's `command` replaces the container entrypoint
3. **Kubernetes `args` overrides CMD**: The chart's `args` replaces the container default command

**Solution**: Use `test-values.yaml` which sets empty `command` and `args` for services:

```bash
helm install mrva k8s/codeql-mrva-chart \
  -f k8s/codeql-mrva-chart/test-values.yaml \
  --namespace mrva-test --create-namespace
```

### MinIO Init Job Failing

Check if MinIO StatefulSet is ready before the job runs:

```bash
kubectl logs -n mrva-test job/mrva-codeql-mrva-chart-minio-init
kubectl describe job -n mrva-test mrva-codeql-mrva-chart-minio-init
```

### RabbitMQ Healthcheck Failing

RabbitMQ has a 30-second initial delay; if still failing:

```bash
kubectl describe pod -n mrva-test -l app.kubernetes.io/component=rabbitmq
kubectl exec -n mrva-test -it <rabbitmq-pod> -- rabbitmq-diagnostics check_port_connectivity
```

## Testing Variations

### Test with Different Values

```bash
# Smaller PVC sizes for constrained environments
helm install mrva k8s/codeql-mrva-chart \
  --namespace mrva-test \
  --create-namespace \
  --set postgres.persistence.size=1Gi \
  --set minio.persistence.size=2Gi \
  --set rabbitmq.persistence.size=1Gi \
  --set server.enabled=false \
  --set agent.enabled=false \
  --set hepc.enabled=false

# Test with external database
helm install mrva k8s/codeql-mrva-chart \
  --namespace mrva-test \
  --create-namespace \
  --set postgres.enabled=false \
  --set postgres.external.host=external-postgres.example.com \
  --set server.enabled=false \
  --set agent.enabled=false \
  --set hepc.enabled=false
```

## Run Helm Tests

```bash
# Run chart tests (requires server to be enabled and running)
helm test mrva -n mrva-test
```

## Test Images Architecture

The `scripts/create-test-images.sh` script creates minimal Flask-based containers for testing:

| Image | Port | Description |
|-------|------|-------------|
| mrva-server:0.4.5 | 8080 | Flask app with `/health` endpoint |
| mrva-agent:0.4.5 | 8071 | Flask app with `/health` endpoint + background worker thread |
| mrva-hepc-container:0.4.5 | 8070 | Flask app with `/health` endpoint |

These images:
- Use `python:3.11-alpine` base (~27MB)
- Respond to `/health` with `{"status": "healthy", "service": "<name>"}`
- Use `CMD` directive (not ENTRYPOINT) for simplicity

The `test-values.yaml` override file:
- Sets empty `args: []` for server and agent (prevents passing `--mode=container` etc.)
- Sets empty `command: []` for hepc (prevents running `hepc-serve-global`)
- Disables optional services (codeserver, ghmrva)

This consistent approach ensures:
1. Test images use simple `CMD` directive
2. All command/arg overrides are in one place (test-values.yaml)
3. Production values.yaml remains unchanged
