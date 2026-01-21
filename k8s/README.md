# Kubernetes Deployment Guide for CodeQL MRVA

This guide covers deploying components of the CodeQL Multi-Repository Variant Analysis (MRVA) system to Kubernetes. We use a progressive "crawl, walk, run" approach, starting simple and building up to full production deployments.

## Overview

The CodeQL MRVA architecture includes several services, but this guide focuses initially on the **HEPC** (HTTP Endpoint Provider for CodeQL) service—specifically the Go implementation [`mrva-go-hepc`](https://github.com/data-douser/mrva-go-hepc).

The HEPC service:

- Serves CodeQL database metadata and files via HTTP
- Supports multiple storage backends: local filesystem or Google Cloud Storage (GCS)
- Provides a `/health` endpoint for Kubernetes health checks
- Exposes `/index` and `/db/{filename}` endpoints for database discovery and retrieval

## Deployment Stages

| Stage            | Description                           | Auth Method                  | Tools    |
| ---------------- | ------------------------------------- | ---------------------------- | -------- |
| 🐛 **Crawl**     | Deploy HEPC only with Helm + SA key   | Service Account JSON Key     | `helm`   |
| 🚶 **Walk**      | Deploy HEPC with Helm + secure auth   | Workload Identity Federation | `helm`   |
| 🏃 **Run**       | Full MRVA stack with Helm             | Workload Identity Federation | `helm`   |

> **Note**: All stages use `helm` CLI for deployment consistency and reproducibility.

## GCS Authentication

The HEPC service uses the **Go GCS client library**, which supports two authentication methods:

| Method | Description | Use Case | Security |
| ------ | ----------- | -------- | -------- |
| **Service Account JSON Key** | RSA key pair exchanged for OAuth 2.0 token | Crawl stage | ⚠️ Requires key rotation |
| **Workload Identity Federation** | Keyless auth via automatic token exchange | Walk/Run stages | ✅ Recommended |

### Understanding Service Accounts

A **service account** is a special kind of account used by applications rather than people:

- Identified by an email address (e.g., `hepc-sa@PROJECT_ID.iam.gserviceaccount.com`)
- Can be granted IAM roles to access Google Cloud resources
- Authenticates using either **JSON keys** (Crawl) or **Workload Identity** (Walk/Run)

> **Security Note**: Service account keys are a security risk if not managed correctly. For production deployments, use [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation-with-kubernetes) instead.

Learn more:

- [Service Accounts Overview](https://cloud.google.com/iam/docs/service-account-overview)
- [Service Account Credentials](https://cloud.google.com/iam/docs/service-account-creds)
- [Service Account Types](https://cloud.google.com/iam/docs/service-account-types)

---

## 🐛 Stage 1: Crawl — Deploy HEPC with Helm

This section demonstrates a "hello world" deployment of just the HEPC service on a remote GKE cluster using Helm, authenticating to a GCS bucket using a service account JSON key.

> **Important**: You must provide your own GCS bucket containing CodeQL databases. The examples below use placeholder names (`YOUR_GCS_BUCKET_NAME`, `your-codeql-bucket`) that you must replace with your actual bucket name.

### Prerequisites

1. **GKE Cluster**: A running GKE cluster with `kubectl` and `helm` configured

   First, ensure the GKE auth plugin is installed (required for `kubectl` to communicate with GKE):

   ```bash
   # Check if plugin is installed
   gke-gcloud-auth-plugin --version

   # If not installed:
   gcloud components install gke-gcloud-auth-plugin
   ```

   Then get credentials for your cluster:

   ```bash
   # Get credentials (updates ~/.kube/config and sets context)
   gcloud container clusters get-credentials CLUSTER_NAME \
     --region REGION \
     --project PROJECT_ID

   # Example:
   # gcloud container clusters get-credentials mrva-gke-test-1 \
   #   --region us-central1 \
   #   --project mrva-gcp-data-test
   ```

   Verify cluster access:

   ```bash
   # Verify cluster access
   kubectl cluster-info
   kubectl get nodes

   # Verify helm is available
   helm version
   ```

   > **Reference**: [Install kubectl and configure cluster access](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl)

2. **GCS Bucket**: Your own GCS bucket containing CodeQL databases in the expected structure:

   ```text
   gs://your-bucket-name/  # Replace with your actual bucket
   ├── owner-repo-xxx/
   │   ├── codeql-database.yml
   │   └── db-javascript/
   └── owner-repo-yyy/
       ├── codeql-database.yml
       └── db-python/
   ```

3. **Service Account with JSON Key**: A GCP service account with `storage.objectViewer` permissions on the bucket

   Create the service account and key via `gcloud`:

   ```bash
   export PROJECT_ID=$(gcloud config get-value project)
   export SA_NAME=hepc-gcs-reader
   export BUCKET_NAME=your-codeql-bucket  # Replace with your bucket

   # Create service account
   gcloud iam service-accounts create $SA_NAME \
     --display-name="HEPC GCS Reader for CodeQL databases"

   # Grant Storage Object Viewer role on the bucket
   gsutil iam ch serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com:objectViewer \
     gs://$BUCKET_NAME

   # Create and download JSON key
   gcloud iam service-accounts keys create ./hepc-sa-key.json \
     --iam-account=$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com
   ```

   > **Security Note**: Store the JSON key securely. Rotate keys regularly and delete unused keys. See [Best Practices for Service Account Keys](https://cloud.google.com/iam/docs/best-practices-for-managing-service-account-keys).

4. **Container Image**: The `mrva-go-hepc` image (publicly available on GHCR)

   ```bash
   # Verify image is accessible
   docker pull ghcr.io/data-douser/mrva-go-hepc:latest
   ```

### Step 1: Create the Namespace

```bash
export NAMESPACE=mrva
kubectl create namespace $NAMESPACE
```

### Step 2: Create the GCS Credentials Secret

Create a secret containing your service account JSON key:

```bash
kubectl create secret generic hepc-gcs-credentials \
  --namespace $NAMESPACE \
  --from-file=credentials.json=/path/to/your-service-account-key.json

# Verify secret was created
kubectl get secret hepc-gcs-credentials -n $NAMESPACE
```

### Step 3: Create values-gke-crawl.yaml

Create a Helm values file for HEPC-only deployment with GCS storage:

```yaml
# values-gke-crawl.yaml
# Minimal HEPC deployment for GKE with GCS storage (Crawl stage)

# Disable all services except HEPC
server:
  enabled: false
agent:
  enabled: false
postgres:
  enabled: false
minio:
  enabled: false
rabbitmq:
  enabled: false
codeserver:
  enabled: false
ghmrva:
  enabled: false

# HEPC Configuration with GCS
hepc:
  enabled: true
  replicaCount: 1
  image:
    repository: ghcr.io/data-douser/codeql-mrva-hepc
    tag: latest
    pullPolicy: Always
  command:
    - "hepc-server"
    - "--storage"
    - "gcs"
    - "--host"
    - "0.0.0.0"
    - "--port"
    - "8070"
    - "--gcs-bucket"
    - "YOUR_GCS_BUCKET_NAME"  # Replace with your bucket
  storage:
    type: gcs
    gcs:
      bucket: "YOUR_GCS_BUCKET_NAME"  # Replace with your bucket
      prefix: ""
      credentialsSecret: "hepc-gcs-credentials"
      credentialsKey: "credentials.json"
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

serviceAccount:
  create: true
  annotations: {}
```

> **Important**: Replace `YOUR_GCS_BUCKET_NAME` with your actual GCS bucket name.

### Step 4: Deploy with Helm

```bash
# Lint the chart first
helm lint k8s/codeql-mrva-chart

# Dry-run to verify templates render correctly
helm install mrva k8s/codeql-mrva-chart \
  --namespace $NAMESPACE \
  -f values-gke-crawl.yaml \
  --dry-run

# Deploy
helm install mrva k8s/codeql-mrva-chart \
  --namespace $NAMESPACE \
  -f values-gke-crawl.yaml \
  --wait --timeout 5m
```

> **⚠️ GKE Autopilot Note**: On Autopilot clusters, the initial `helm install` may timeout during node auto-scaling. This is expected—the pod is often running even when Helm reports failure. Check with `kubectl get pods -n $NAMESPACE` and if the pod is Running, use `helm upgrade` with the same arguments to fix the release status.

### Step 5: Verify the Deployment

```bash
# Check helm release status
helm status mrva -n $NAMESPACE

# Check pod status (should show Running 1/1)
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=hepc

# View logs - look for "Starting server on 0.0.0.0:8070"
kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=hepc

# Test the health endpoint via port-forward
kubectl port-forward -n $NAMESPACE svc/mrva-codeql-mrva-chart-hepc 8070:8070 &
sleep 2  # Allow port-forward to establish

# Test health endpoint
curl -s http://localhost:8070/health
# Expected: {"status":"ok","storage_type":"gcs","has_metadata_db":true}

# Test index endpoint (newline-delimited JSON)
curl -s http://localhost:8070/index | head -5

# Stop port-forward when done
pkill -f "port-forward.*8070"
```

#### Success Criteria

Your deployment is working when:

| Endpoint | Expected Response | Meaning |
| -------- | ----------------- | ------- |
| `/health` | `{"status":"ok","storage_type":"gcs","has_metadata_db":true}` | GCS connected successfully |
| `/index` | JSON lines with database metadata | Databases found in bucket |

### Troubleshooting

| Issue | Solution |
| ----- | -------- |
| Helm timeout on Autopilot | Pod may be running; check `kubectl get pods`, then `helm upgrade` |
| Pod in `Pending` | GKE Autopilot scaling nodes; wait 2-3 minutes |
| Pod in `CrashLoopBackOff` | Check logs: `kubectl logs -n $NAMESPACE <pod-name>` |
| GCS permission denied | Verify service account has `roles/storage.objectViewer` |
| Secret not found | Ensure secret is in the same namespace as the deployment |
| Image pull error | Verify GHCR image is accessible |
| `bucket not found` | Verify bucket name in `values-gke-crawl.yaml` |
| Empty `/index` response | Verify bucket has directories with `codeql-database.yml` files |
| `/health` shows `local` storage | GCS credentials not mounted; check secret name/key |

### Cleanup

```bash
# Remove Helm release
helm uninstall mrva -n $NAMESPACE

# Delete namespace (removes all resources including secrets)
kubectl delete namespace $NAMESPACE
```

#### Security: Clean Up Service Account Key

After testing, clean up the JSON key for security:

```bash
# Delete local key file
rm ./hepc-sa-key.json

# Optionally revoke the key in GCP
gcloud iam service-accounts keys list \
  --iam-account=$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com

gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com
```

> **Tip**: For ongoing development, consider progressing to Stage 2 (Walk) with Workload Identity to avoid managing keys.

---

## 🚶 Stage 2: Walk — Deploy HEPC with Helm + Workload Identity Federation

> **Status**: 🚧 Coming Soon

This stage introduces:

- **Workload Identity Federation** for secure, keyless authentication to GCS
- **ServiceAccount token volume projection** for automatic credential management
- **Service account impersonation** without managing long-lived keys

### Key Concepts

**Workload Identity Federation** allows Kubernetes workloads to authenticate to Google Cloud without managing service account keys. Instead:

1. A Kubernetes ServiceAccount is bound to a GCP IAM principal
2. The pod receives a projected ServiceAccount token
3. The token is exchanged for GCP credentials automatically

References:

- [GCP Workload Identity Federation with Kubernetes](https://cloud.google.com/iam/docs/workload-identity-federation-with-kubernetes)
- [Kubernetes ServiceAccount Token Volume Projection](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#serviceaccount-token-volume-projection)

### Prerequisites for Workload Identity

1. Enable required GCP APIs:

   ```bash
   gcloud services enable \
     iam.googleapis.com \
     cloudresourcemanager.googleapis.com \
     iamcredentials.googleapis.com \
     sts.googleapis.com
   ```

2. Create a Workload Identity Pool and Provider
3. Configure IAM bindings for the Kubernetes ServiceAccount
4. Update Helm values to use Workload Identity

### Helm Values for Workload Identity (Preview)

```yaml
# values-walk.yaml
hepc:
  enabled: true
  image:
    repository: ghcr.io/data-douser/mrva-go-hepc
    tag: latest
  command:
    - "hepc-server"
    - "--storage"
    - "gcs"
    - "--host"
    - "0.0.0.0"
    - "--port"
    - "8070"
    - "--gcs-bucket"
    - "YOUR_GCS_BUCKET_NAME"
  storage:
    type: gcs
    gcs:
      bucket: "YOUR_GCS_BUCKET_NAME"
      prefix: ""
      # No credentialsSecret needed with Workload Identity!

serviceAccount:
  create: true
  annotations:
    # Link to GCP service account via Workload Identity
    iam.gke.io/gcp-service-account: "hepc-gcs-reader@YOUR_PROJECT.iam.gserviceaccount.com"
```

*Full documentation coming soon...*

---

## 🏃 Stage 3: Run — Full MRVA Stack with Helm

> **Status**: 🚧 Coming Soon

This stage deploys the complete CodeQL MRVA architecture:

- **Server**: MRVA coordinator service
- **Agent**: CodeQL analysis workers
- **HEPC**: Database provider (with Workload Identity)
- **PostgreSQL**: Metadata database
- **MinIO**: Object storage for results
- **RabbitMQ**: Message queue for job coordination

### Quick Start (Preview)

```bash
# Add any required Helm repos
# helm repo add ...

# Install the full stack
helm install mrva ./codeql-mrva-chart \
  --namespace mrva \
  --create-namespace \
  -f production-values.yaml
```

### Architecture Diagram

```text
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │  Server  │  │  Agent   │  │   HEPC   │  │ RabbitMQ │    │
│  │  :8080   │  │  :8071   │  │  :8070   │  │  :5672   │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │             │             │             │           │
│       └─────────────┴──────┬──────┴─────────────┘           │
│                            │                                 │
│  ┌──────────┐  ┌──────────┴───────────┐                     │
│  │PostgreSQL│  │        MinIO         │                     │
│  │  :5432   │  │        :9000         │                     │
│  └──────────┘  └──────────────────────┘                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                    ┌──────────────┐
                    │  GCS Bucket  │
                    │  (CodeQL DBs)│
                    └──────────────┘
```

*Full documentation coming soon...*

---

## Additional Resources

### Project Documentation

- [mrva-go-hepc README](https://github.com/data-douser/mrva-go-hepc/blob/main/README.md)
- [codeql-mrva-chart](./codeql-mrva-chart/) - Helm chart for full MRVA deployment

### GCP Service Accounts

- [Service Accounts Overview](https://cloud.google.com/iam/docs/service-account-overview) - What service accounts are
- [Service Account Credentials](https://cloud.google.com/iam/docs/service-account-creds) - JSON keys vs short-lived credentials
- [Service Account Types](https://cloud.google.com/iam/docs/service-account-types) - User-managed, default, and service agents
- [Service Account Impersonation](https://cloud.google.com/iam/docs/service-account-impersonation) - How Workload Identity works
- [Create Service Accounts](https://cloud.google.com/iam/docs/service-accounts-create) - Creating and managing
- [Best Practices for Service Account Keys](https://cloud.google.com/iam/docs/best-practices-for-managing-service-account-keys)

### GKE and Workload Identity

- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Workload Identity Federation with Kubernetes](https://cloud.google.com/iam/docs/workload-identity-federation-with-kubernetes)

### Helm

- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)

## Contributing

When updating this documentation:

1. Test all commands on a real cluster before documenting
2. Keep examples minimal but complete
3. Update the status badges as stages are completed
4. Add troubleshooting entries as issues are discovered
