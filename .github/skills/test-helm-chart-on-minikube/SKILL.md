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

There are three deployment approaches depending on your image availability:

| Approach | Use Case | Images Required |
| -------- | -------- | --------------- |
| [Public GHCR Images](#recommended-deployment-with-public-ghcr-images) | **Recommended** - Production-like testing | None (pulls from GHCR) |
| [Local Test Images](#deployment-with-local-test-images) | Offline testing or custom builds | Built locally via script |
| [Infrastructure Only](#infrastructure-only-deployment-no-custom-images) | Database/messaging testing | None (uses public images) |

### Recommended: Deployment with Public GHCR Images

All custom container images are now **publicly available** on GitHub Container Registry (GHCR) and can be pulled without authentication.

#### GHCR Image Status

| Image | Repository | Purpose | Public Status |
| ----- | ---------- | ------- | ------------- |
| `ghcr.io/data-douser/codeql-mrva-server` | [mrva-docker](https://github.com/data-douser/mrva-docker) | MRVA coordination server | ✅ Public |
| `ghcr.io/data-douser/codeql-mrva-agent` | [mrva-docker](https://github.com/data-douser/mrva-docker) | CodeQL analysis agent | ✅ Public |
| `ghcr.io/data-douser/codeql-mrva-hepc` | [mrva-go-hepc](https://github.com/data-douser/mrva-go-hepc) | HTTP Endpoint Provider for CodeQL | ✅ Public |

#### Verify Public Image Access

Test that images can be pulled without authentication:

```bash
# Remove any cached credentials (ensures clean test)
docker logout ghcr.io

# Test pulling each image - should work without auth
docker pull ghcr.io/data-douser/codeql-mrva-server:latest
docker pull ghcr.io/data-douser/codeql-mrva-agent:latest
docker pull ghcr.io/data-douser/codeql-mrva-hepc:latest
```

If you see `unauthorized` or `denied` errors, see [GHCR Troubleshooting](#ghcr-image-troubleshooting).

#### Deploy with minikube-values.yaml (Recommended)

Use `minikube-values.yaml` which is specifically configured for local Minikube testing:

```bash
helm install mrva k8s/codeql-mrva-chart \
  -f k8s/codeql-mrva-chart/production-values.yaml \
  -f k8s/codeql-mrva-chart/minikube-values.yaml \
  --namespace mrva-test \
  --create-namespace \
  --set postgres.auth.password=testpassword \
  --set minio.rootPassword=testpassword123 \
  --set rabbitmq.auth.password=testpassword \
  --wait --timeout 5m
```

The `minikube-values.yaml` overlay provides:

| Configuration | Value | Purpose |
| ------------- | ----- | ------- |
| `global.imagePullSecrets` | `[]` (empty) | No auth needed for public GHCR images |
| `global.imagePullPolicy` | `Always` | Ensure latest images are pulled |
| `ingress.enabled` | `false` | No ingress controller needed locally |
| `networkPolicy.enabled` | `false` | Simpler local networking |
| Resource limits | Reduced | Fits constrained Minikube environments |
| PVC sizes | Smaller (1-2Gi) | Saves local storage |

#### Alternative: Deploy with production-values.yaml Only

For production-like testing with larger resources:

```bash
helm install mrva k8s/codeql-mrva-chart \
  -f k8s/codeql-mrva-chart/production-values.yaml \
  --namespace mrva-test \
  --create-namespace \
  --set global.imagePullSecrets=[] \
  --set global.imagePullPolicy=Always \
  --set ingress.enabled=false \
  --set postgres.auth.password=testpassword \
  --set minio.rootPassword=testpassword123 \
  --set rabbitmq.auth.password=testpassword \
  --wait --timeout 5m
```

> **Note**: Override `imagePullSecrets=[]` since GHCR images are now public.

### Deployment with Local Test Images

For offline testing or when you want to use custom-built images instead of GHCR, use the provided test image script to create minimal Flask-based containers that respond to health checks:

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

### Deployment with Locally-Built Production Images

If you've built production images locally:

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
| ------------- | ---- | --------------- |
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
| ------------- | ---- | --------------- |
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
| ----- | ---- | ----------- |
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

## GHCR Image Troubleshooting

### Current Public Image Status

All custom MRVA images are now **publicly available** on GHCR:

```bash
# Verify public access (should work without authentication)
docker logout ghcr.io
docker pull ghcr.io/data-douser/codeql-mrva-server:latest
docker pull ghcr.io/data-douser/codeql-mrva-agent:latest
docker pull ghcr.io/data-douser/codeql-mrva-hepc:latest
```

### Common GHCR Issues

| Symptom | Cause | Solution |
| ------- | ----- | -------- |
| `denied: denied` | Package is private | Change visibility to Public in Package settings |
| `unauthorized: authentication required` | Package not public | Make package public OR create imagePullSecret |
| `manifest unknown` | Tag doesn't exist | Check available tags at package page |
| `repository not found` | Wrong path or private | Verify repository and visibility |

### GitHub Actions Workflow Considerations

The `docker-publish.yml` workflow builds and publishes images to GHCR. Key configurations:

| Setting | Value | Purpose |
| ------- | ----- | ------- |
| `permissions.packages` | `write` | Required at workflow level for GHCR push |
| `provenance` | `false` | Avoids attestation permission issues |
| `sbom` | `false` | Avoids attestation permission issues |
| QEMU setup | Removed | Not needed for single-arch (amd64) builds |

If you encounter `permission_denied: write_package` errors in CI:

1. Ensure workflow has top-level `permissions: packages: write`
2. Check repository Settings → Actions → General → Workflow permissions
3. Verify the package allows workflow write access

### Making GHCR Packages Public (If Needed)

Packages published to GHCR default to **private**. To enable anonymous pulls:

1. Go to `https://github.com/users/<owner>/packages/container/package/<image-name>`
2. Click **Package settings** (gear icon)
3. Under **Danger Zone**, click **Change visibility**
4. Select **Public** → Confirm with package name

> **Warning**: Once public, you cannot make a package private again.

### Alternative: Publish to Docker Hub

If GHCR public access is problematic, consider Docker Hub as an alternative:

```bash
# Tag for Docker Hub
docker tag ghcr.io/data-douser/codeql-mrva-hepc:latest datadouser/codeql-mrva-hepc:latest

# Push to Docker Hub (requires login)
docker login
docker push datadouser/codeql-mrva-hepc:latest
```

Then update `values.yaml` or use `--set`:

```bash
helm install mrva k8s/codeql-mrva-chart \
  --set hepc.image.repository=datadouser/codeql-mrva-hepc \
  ...
```

### Alternative: Use Google Artifact Registry

For GKE deployments, Google Artifact Registry provides better integration:

```bash
# Configure Docker for Artifact Registry
gcloud auth configure-docker us-docker.pkg.dev

# Tag and push
docker tag ghcr.io/data-douser/codeql-mrva-hepc:latest \
  us-docker.pkg.dev/PROJECT_ID/mrva/codeql-mrva-hepc:latest
docker push us-docker.pkg.dev/PROJECT_ID/mrva/codeql-mrva-hepc:latest
```

## GKE Deployment with Workload Identity

For deploying to Google Kubernetes Engine (GKE) with GCS backend storage for HEPC, use Workload Identity Federation for GKE.

### GKE Prerequisites

- GKE cluster with Workload Identity enabled
- GCS bucket for HEPC data
- IAM permissions to create service accounts and bindings

### Setup Workload Identity

```bash
# Set variables
PROJECT_ID=your-project-id
GKE_SA_NAME=mrva-workload
GKE_SA_NAMESPACE=mrva
GSA_NAME=mrva-gcs-access

# Create Google Service Account (GSA)
gcloud iam service-accounts create $GSA_NAME \
  --display-name="MRVA GCS Access"

# Grant GCS access to the GSA
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# Allow Kubernetes SA to impersonate Google SA
gcloud iam service-accounts add-iam-policy-binding \
  $GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[$GKE_SA_NAMESPACE/$GKE_SA_NAME]"
```

### Deploy with GCS Backend

```bash
helm install mrva k8s/codeql-mrva-chart \
  -f k8s/codeql-mrva-chart/production-values.yaml \
  --namespace mrva \
  --create-namespace \
  --set serviceAccount.create=true \
  --set serviceAccount.name=mrva-workload \
  --set serviceAccount.annotations."iam\.gke\.io/gcp-service-account"="mrva-gcs-access@PROJECT_ID.iam.gserviceaccount.com" \
  --set hepc.command="{hepc-server,--storage,gcs,--host,0.0.0.0,--port,8070}" \
  --set hepc.gcs.bucket=your-hepc-bucket \
  --set postgres.auth.password=secure-password \
  --set minio.rootPassword=secure-password-123 \
  --set rabbitmq.auth.password=secure-password \
  --wait --timeout 5m
```

### Verify Workload Identity

```bash
# Check if the pod can access GCS
kubectl exec -n mrva deploy/mrva-codeql-mrva-chart-hepc -- \
  wget -q -O- "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" \
  -H "Metadata-Flavor: Google"

# Should output: mrva-gcs-access@PROJECT_ID.iam.gserviceaccount.com
```

### References

- [Workload Identity Federation for GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Configuring Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#enable_on_cluster)
