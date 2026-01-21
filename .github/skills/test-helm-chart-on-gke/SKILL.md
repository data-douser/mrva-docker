---
name: test-helm-chart-on-gke
description: Skill for testing the deployment of `codeql-mrva-chart` helm chart on a remote Google Kubernetes Engine (GKE) cluster.
---

# Skill `test-helm-chart-on-gke`

Test the `codeql-mrva-chart` Helm deployment on a remote GKE cluster, starting with HEPC-only deployment using GCS storage.

## Overview

This skill follows a progressive "crawl, walk, run" approach:

| Stage | Description | Auth Method | Tools |
| ----- | ----------- | ----------- | ----- |
| 🐛 **Crawl** | HEPC only with Service Account JSON key | SA JSON Key | `helm` |
| 🚶 **Walk** | HEPC only with Workload Identity Federation | WIF | `helm` |
| 🏃 **Run** | Full MRVA stack with Workload Identity | WIF | `helm` |

> **Note**: All stages use `helm` CLI for deployment consistency and reproducibility.

## GCS Authentication Methods

The `mrva-go-hepc` service uses the **Go GCS client library**, which supports two authentication methods:

| Method | Description | Use Case | Security |
| ------ | ----------- | -------- | -------- |
| **Service Account JSON Key** | RSA key pair for OAuth 2.0 | Crawl stage, simple setup | ⚠️ Key must be rotated |
| **Workload Identity Federation** | Keyless auth via token exchange | Walk/Run stages | ✅ Recommended |

### Understanding Service Accounts

A **service account** is a special kind of account typically used by applications or compute workloads rather than people. Service accounts:

- Are identified by an email address (e.g., `hepc-gcs-reader@PROJECT_ID.iam.gserviceaccount.com`)
- Can be granted IAM roles to access Google Cloud resources
- Authenticate using either **JSON keys** (Crawl stage) or **Workload Identity** (Walk/Run stages)

### Service Account Credential Types

| Credential Type | Description | Lifetime | Recommended |
| --------------- | ----------- | -------- | ----------- |
| **JSON Key** | RSA public/private key pair, exchanged for OAuth 2.0 access token | Long-lived (until deleted) | ⚠️ Dev/test only |
| **Short-lived Credentials** | Automatically obtained via attached SA or Workload Identity | 1 hour default | ✅ Production |

> **Security Warning**: Service account keys are a security risk if not managed correctly. You should [choose a more secure alternative](https://cloud.google.com/docs/authentication#auth-decision-tree) whenever possible. For production, use **Workload Identity Federation**.

### Service Account Impersonation (Walk Stage Prep)

For the Walk stage, we use **Workload Identity Federation** which works via service account impersonation:

1. A Kubernetes ServiceAccount is bound to a GCP IAM principal
2. Workloads receive a projected ServiceAccount token
3. The token is exchanged for GCP credentials automatically

This eliminates the need to manage service account keys while maintaining fine-grained access control.

References:

- [Service Accounts Overview](https://cloud.google.com/iam/docs/service-account-overview)
- [Service Account Credentials](https://cloud.google.com/iam/docs/service-account-creds)
- [Service Account Types](https://cloud.google.com/iam/docs/service-account-types)
- [Service Account Impersonation](https://cloud.google.com/iam/docs/service-account-impersonation)

## Prerequisites

### Required Access

- **GKE Cluster**: Active `kubectl` context with admin deployment privileges
- **GCS Bucket**: Your own GCS bucket containing CodeQL databases (see structure below)
- **IAM Permissions**: Ability to create/manage service accounts and IAM bindings

> **Important**: You must provide your own GCS bucket. The examples in this guide use placeholder bucket names that you must replace with your actual bucket.

### Create a Service Account for GCS Access

If you don't have a service account yet:

```bash
export PROJECT_ID=$(gcloud config get-value project)
export SA_NAME=hepc-gcs-reader

# Create service account
gcloud iam service-accounts create $SA_NAME \
  --display-name="HEPC GCS Reader for CodeQL databases"

# Grant Storage Object Viewer role on the bucket
gsutil iam ch serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com:objectViewer \
  gs://YOUR_BUCKET_NAME

# Create and download JSON key
gcloud iam service-accounts keys create ./hepc-sa-key.json \
  --iam-account=$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com

# Verify the key was created
ls -la ./hepc-sa-key.json
```

> **Security Note**: Store the JSON key securely. After creation, you cannot retrieve the private key again. Rotate keys regularly and delete unused keys.

### Verify Cluster Access

After configuring GKE access (see above), verify connectivity:

```bash
# Verify kubectl context is set to GKE cluster
kubectl config current-context

# Should show something like: gke_PROJECT_ID_REGION_CLUSTER_NAME
kubectl cluster-info

# Verify nodes are accessible
kubectl get nodes

# Verify you can create namespaces
kubectl auth can-i create namespace
```

### Required Tools

| Tool | Version | Verify Command |
| ---- | ------- | -------------- |
| `kubectl` | 1.25+ | `kubectl version --client` |
| `helm` | 3.x | `helm version` |
| `gcloud` | Latest | `gcloud version` |
| `gke-gcloud-auth-plugin` | Latest | `gke-gcloud-auth-plugin --version` |

### Install GKE Auth Plugin

The `gke-gcloud-auth-plugin` is **required** for `kubectl` to authenticate with GKE clusters. Without it, `kubectl` commands will fail.

```bash
# Check if plugin is already installed
gke-gcloud-auth-plugin --version

# If not installed, install it:
gcloud components install gke-gcloud-auth-plugin
```

> **Note**: This plugin uses the [Client-go Credential Plugins](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#client-go-credential-plugins) framework to provide authentication tokens for GKE cluster communication.

Reference: [Install kubectl and configure cluster access](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_plugin)

### Configure GKE Cluster Access

After installing the auth plugin, get credentials for your GKE cluster:

```bash
# Get credentials for your cluster (updates ~/.kube/config)
gcloud container clusters get-credentials CLUSTER_NAME \
  --region REGION \
  --project PROJECT_ID

# Example:
# gcloud container clusters get-credentials mrva-gke-test-1 \
#   --region us-central1 \
#   --project mrva-gcp-data-test

# Verify the context was set
kubectl config current-context
# Should show: gke_PROJECT_ID_REGION_CLUSTER_NAME
```

## GKE Cluster Types

GKE offers different cluster modes. This skill supports both:

| Mode | Description | Workload Identity Support |
| ---- | ----------- | ------------------------- |
| **Standard** | Full control over node configuration | ✅ Full support |
| **Autopilot** | Managed node infrastructure | ✅ Full support |

Reference: [GKE Deployment Options](https://cloud.google.com/kubernetes-engine/enterprise/docs/deployment-options)

---

## 🐛 Stage 1: Crawl — Deploy HEPC with Helm + Service Account Key

Deploy only the HEPC service using Helm, authenticating to GCS with a service account JSON key.

### Step 1: Create Test Namespace

```bash
export NAMESPACE=mrva-test
kubectl create namespace $NAMESPACE
```

### Step 2: Create GCS Credentials Secret

```bash
# Create secret from service account JSON key file
kubectl create secret generic hepc-gcs-credentials \
  --namespace $NAMESPACE \
  --from-file=credentials.json=./hepc-sa-key.json

# Verify secret was created
kubectl get secret hepc-gcs-credentials -n $NAMESPACE
```

### Step 3: Create values-gke-crawl.yaml

Copy the template file and customize it with your GCS bucket name:

```bash
# Copy the template
cp .github/skills/test-helm-chart-on-gke/values-gke-crawl.yaml.template ./values-gke-crawl.yaml

# Edit and replace YOUR_GCS_BUCKET_NAME with your actual bucket
# On macOS/Linux:
sed -i '' 's/YOUR_GCS_BUCKET_NAME/my-actual-bucket/g' ./values-gke-crawl.yaml

# Or edit manually in your preferred editor
```

The template file is located at: [values-gke-crawl.yaml.template](./values-gke-crawl.yaml.template)

> **Important**: Replace `YOUR_GCS_BUCKET_NAME` in both the `command` args and `storage.gcs.bucket` fields.

### Step 4: Deploy with Helm

```bash
# Lint the chart first
helm lint k8s/codeql-mrva-chart

# Dry-run to verify templates
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

> **⚠️ GKE Autopilot Note**: On Autopilot clusters, the initial `helm install` may timeout during node auto-scaling. This is expected behavior—the pod is often running even when Helm reports failure. See recovery steps below.

#### Recovery from Autopilot Timeout

If `helm install` fails with timeout but pods are running:

```bash
# Check if pod is actually running
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=hepc

# If pod is Running, fix the Helm release status with upgrade
helm upgrade mrva k8s/codeql-mrva-chart \
  --namespace $NAMESPACE \
  -f values-gke-crawl.yaml \
  --wait --timeout 5m

# Verify release status is now "deployed"
helm status mrva -n $NAMESPACE
```

### Step 5: Verify Deployment

```bash
# Check pod status (should show Running 1/1)
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=hepc

# View logs - look for "Starting server on 0.0.0.0:8070"
kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=hepc

# Check events if pod not running
kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/component=hepc
```

### Step 6: Test HEPC Endpoints

```bash
# Port-forward to access locally (background with sleep for reliability)
kubectl port-forward -n $NAMESPACE svc/mrva-codeql-mrva-chart-hepc 8070:8070 &
sleep 2  # Allow port-forward to establish

# Test health endpoint
curl -s http://localhost:8070/health
# Expected: {"status":"ok","storage_type":"gcs","has_metadata_db":true}

# Test index endpoint (newline-delimited JSON, one database per line)
curl -s http://localhost:8070/index | head -5
# Expected: JSON objects like {"name":"owner/repo","language":"javascript",...}

# Count databases found
curl -s http://localhost:8070/index | wc -l

# Kill port-forward when done
pkill -f "port-forward.*8070"
```

#### Success Criteria

| Endpoint | Expected Response | Meaning |
| -------- | ----------------- | ------- |
| `/health` | `{"status":"ok","storage_type":"gcs","has_metadata_db":true}` | GCS connected, metadata DB available |
| `/index` | Newline-delimited JSON | Databases discovered in GCS bucket |

### Troubleshooting Crawl Stage

| Issue | Diagnosis | Solution |
| ----- | --------- | -------- |
| Helm timeout on Autopilot | `kubectl get pods -n $NAMESPACE` | Pod may be running; use `helm upgrade` to fix status |
| Pod `CrashLoopBackOff` | `kubectl logs -n $NAMESPACE <pod>` | Check GCS bucket name/credentials |
| Pod `Pending` | `kubectl describe pod` | Autopilot scaling; wait 2-3 min for node provisioning |
| `permission denied` in logs | IAM permissions | Grant `roles/storage.objectViewer` to SA |
| Secret not found | `kubectl get secret -n $NAMESPACE` | Verify secret in correct namespace |
| Image pull error | `kubectl describe pod` | Verify GHCR image accessibility |
| `bucket not found` | Wrong bucket name | Check `--gcs-bucket` value |
| Empty `/index` response | No databases in bucket | Verify bucket has `codeql-database.yml` files |

### Cleanup Crawl Stage

```bash
# Remove Helm release
helm uninstall mrva -n $NAMESPACE

# Delete namespace (removes all resources including secrets)
kubectl delete namespace $NAMESPACE
```

#### Security: Clean Up Service Account Key

After testing, delete or secure the JSON key file:

```bash
# Option 1: Delete local key file
rm ./hepc-sa-key.json

# Option 2: Revoke the key in GCP (recommended)
gcloud iam service-accounts keys list \
  --iam-account=$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com

# Delete specific key by KEY_ID
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com
```

> **Security Note**: Service account keys should be deleted after testing. For ongoing development, consider progressing to the Walk stage with Workload Identity.

---

## 🚶 Stage 2: Walk — Deploy HEPC with Workload Identity Federation

> **Status**: 🚧 Coming Soon

This stage removes the need for service account keys by using GKE Workload Identity Federation.

### Key Concepts

**Workload Identity Federation** (WIF) allows Kubernetes workloads to authenticate to Google Cloud without managing service account keys:

1. A Kubernetes ServiceAccount is annotated with a GCP service account email
2. GKE provides projected tokens that can be exchanged for GCP credentials
3. Applications use ADC (Application Default Credentials) automatically

### Prerequisites for Walk Stage

1. **Enable Workload Identity on GKE cluster**:

   ```bash
   # Check if Workload Identity is enabled
   gcloud container clusters describe CLUSTER_NAME \
     --region REGION \
     --format="value(workloadIdentityConfig.workloadPool)"
   ```

2. **Create GCP Service Account for HEPC**:

   ```bash
   export PROJECT_ID=$(gcloud config get-value project)
   export GSA_NAME=hepc-gcs-reader

   # Create GCP service account
   gcloud iam service-accounts create $GSA_NAME \
     --display-name="HEPC GCS Reader"

   # Grant GCS read access
   gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member="serviceAccount:$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/storage.objectViewer"
   ```

3. **Bind KSA to GSA**:

   ```bash
   export NAMESPACE=mrva-test
   export KSA_NAME=mrva-codeql-mrva-chart  # Default from Helm chart

   gcloud iam service-accounts add-iam-policy-binding \
     $GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com \
     --member="serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/$KSA_NAME]" \
     --role="roles/iam.workloadIdentityUser"
   ```

### values-gke-walk.yaml Preview

```yaml
# values-gke-walk.yaml
# HEPC deployment with Workload Identity Federation (Walk stage)

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

hepc:
  enabled: true
  image:
    repository: ghcr.io/data-douser/codeql-mrva-hepc
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
      # No credentialsSecret - using Workload Identity!

serviceAccount:
  create: true
  annotations:
    iam.gke.io/gcp-service-account: "hepc-gcs-reader@YOUR_PROJECT.iam.gserviceaccount.com"
```

*Full Walk stage documentation coming soon...*

References:

- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Workload Identity Federation with Kubernetes](https://cloud.google.com/iam/docs/workload-identity-federation-with-kubernetes)
- [ServiceAccount Token Volume Projection](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#serviceaccount-token-volume-projection)

---

## 🏃 Stage 3: Run — Full MRVA Stack with Workload Identity

> **Status**: 🚧 Coming Soon

Deploy the complete CodeQL MRVA architecture on GKE with Workload Identity for HEPC.

### Components

| Component | Description | Storage |
| --------- | ----------- | ------- |
| Server | MRVA coordinator | PostgreSQL |
| Agent | CodeQL analysis workers | MinIO |
| HEPC | Database provider | GCS (via WIF) |
| PostgreSQL | Metadata database | PVC |
| MinIO | Results storage | PVC |
| RabbitMQ | Job queue | PVC |

### Deployment Preview

```bash
helm install mrva k8s/codeql-mrva-chart \
  --namespace mrva \
  --create-namespace \
  -f k8s/codeql-mrva-chart/production-values.yaml \
  -f values-gke-run.yaml \
  --set postgres.auth.password=$PG_PASSWORD \
  --set minio.rootPassword=$MINIO_PASSWORD \
  --set rabbitmq.auth.password=$RABBITMQ_PASSWORD \
  --wait --timeout 10m
```

*Full Run stage documentation coming soon...*

---

## Validation Commands

### Check Helm Release

```bash
# Release status
helm status mrva -n $NAMESPACE

# Release history
helm history mrva -n $NAMESPACE

# Get deployed values
helm get values mrva -n $NAMESPACE
```

### Check Kubernetes Resources

```bash
# All resources
kubectl get all -n $NAMESPACE

# Pods with labels
kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/instance=mrva" -o wide

# Services
kubectl get svc -n $NAMESPACE

# ConfigMaps and Secrets
kubectl get configmaps,secrets -n $NAMESPACE

# Events (useful for debugging)
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'
```

### Check Pod Health

```bash
# Describe pod for events
kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/component=hepc

# Check container logs
kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=hepc --tail=50

# Follow logs
kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=hepc -f
```

---

## Common Issues and Solutions

### GCS Authentication Errors

| Error | Cause | Solution |
| ----- | ----- | -------- |
| `could not find default credentials` | No credentials mounted | Verify `GOOGLE_APPLICATION_CREDENTIALS` env var |
| `permission denied` | IAM permissions | Grant `roles/storage.objectViewer` |
| `bucket not found` | Wrong bucket name | Check bucket name in command args |
| `invalid_grant` (WIF) | Token exchange failed | Verify WIF configuration |

### Pod Scheduling Issues

| Issue | Cause | Solution |
| ----- | ----- | -------- |
| `Pending` indefinitely | No nodes available | Check node pool capacity |
| `FailedScheduling` | Resource constraints | Reduce resource requests |
| `Unschedulable` (Autopilot) | Unsupported config | Remove nodeSelector/affinity |

### Image Pull Issues

```bash
# Verify image is accessible
docker pull ghcr.io/data-douser/codeql-mrva-hepc:latest

# Check image pull events
kubectl describe pod -n $NAMESPACE <pod-name> | grep -A5 Events
```

---

## GKE-Specific Considerations

### Autopilot Clusters

Autopilot has some restrictions:

- No `nodeSelector` or custom node affinity
- Resource requests/limits are enforced
- Some security contexts may be restricted

### Network Policies

If using GKE network policies, ensure HEPC can:

- Egress to GCS endpoints (`*.googleapis.com`)
- Ingress from services that need database access

### Private Clusters

For private GKE clusters:

- Ensure Cloud NAT is configured for GCS egress
- Or use Private Google Access for GCS

---

## References

### Skill Resources

- [values-gke-crawl.yaml.template](./values-gke-crawl.yaml.template) - Template values file for Crawl stage deployment

### Project Documentation

- [k8s/README.md](../../../k8s/README.md) - User-facing deployment guide
- [codeql-mrva-chart values.yaml](../../../k8s/codeql-mrva-chart/values.yaml) - Full values reference
- [mrva-go-hepc](https://github.com/data-douser/mrva-go-hepc) - HEPC implementation

### GCP Service Accounts

- [Service Accounts Overview](https://cloud.google.com/iam/docs/service-account-overview) - What service accounts are and how they work
- [Service Account Types](https://cloud.google.com/iam/docs/service-account-types) - User-managed, default, and service agents
- [Service Account Credentials](https://cloud.google.com/iam/docs/service-account-creds) - JSON keys vs short-lived credentials
- [Service Account Impersonation](https://cloud.google.com/iam/docs/service-account-impersonation) - How WIF uses impersonation
- [Create Service Accounts](https://cloud.google.com/iam/docs/service-accounts-create) - Creating and managing service accounts
- [Best Practices for Service Account Keys](https://cloud.google.com/iam/docs/best-practices-for-managing-service-account-keys) - Security guidance

### GKE Cluster Access and Authentication

- [Install kubectl and configure cluster access](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl) - GKE auth plugin and kubectl setup
- [GKE Deployment Options](https://cloud.google.com/kubernetes-engine/enterprise/docs/deployment-options)

### Workload Identity

- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Workload Identity Federation with Kubernetes](https://cloud.google.com/iam/docs/workload-identity-federation-with-kubernetes)
- [ServiceAccount Token Volume Projection](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#serviceaccount-token-volume-projection)

### Additional GCS Resources

- [Setup GCS Bucket and Service Account](https://docs.vectorize.io/build-deploy/external-service-setup/how-to/gcs/setup-a-gcs-bucket/) - Step-by-step guide with screenshots
