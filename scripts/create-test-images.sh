#!/usr/bin/env bash
#
# create-test-images.sh
#
# Create minimal test container images for validating the codeql-mrva-chart
# deployment on minikube. These are NOT production images - they are simple
# containers that start successfully and respond to health checks.
#
# Usage:
#   ./scripts/create-test-images.sh [--load]
#
# Options:
#   --load    Also load images into minikube after building
#   --tag     Custom tag (default: 0.4.5)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TAG="${TAG:-0.4.5}"
LOAD_TO_MINIKUBE=false

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --load) LOAD_TO_MINIKUBE=true; shift ;;
        --tag) TAG="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Create temp directory for Dockerfiles
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

log_info "Creating test images with tag: $TAG"
log_info "Temp directory: $TEMP_DIR"

# =============================================================================
# mrva-server - HTTP server that responds to /health
# =============================================================================
log_info "Building mrva-server:$TAG (test image)..."
cat > "$TEMP_DIR/Dockerfile.server" << 'EOF'
FROM python:3.11-alpine
RUN pip install flask
WORKDIR /app
COPY server.py .
EXPOSE 8080
CMD ["python", "server.py"]
EOF

cat > "$TEMP_DIR/server.py" << 'EOF'
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "mrva-server"})

@app.route('/')
def root():
    return jsonify({"service": "mrva-server", "version": os.environ.get("VERSION", "test")})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOF

docker build -t "mrva-server:$TAG" -f "$TEMP_DIR/Dockerfile.server" "$TEMP_DIR"
log_success "Built mrva-server:$TAG"

# =============================================================================
# mrva-agent - Simple agent that runs indefinitely
# =============================================================================
log_info "Building mrva-agent:$TAG (test image)..."
cat > "$TEMP_DIR/Dockerfile.agent" << 'EOF'
FROM python:3.11-alpine
RUN pip install flask
WORKDIR /app
COPY agent.py .
EXPOSE 8071
CMD ["python", "agent.py"]
EOF

cat > "$TEMP_DIR/agent.py" << 'EOF'
from flask import Flask, jsonify
import os
import time
import threading

app = Flask(__name__)

def worker():
    """Simulated worker that processes jobs"""
    while True:
        print("[agent] Waiting for jobs...")
        time.sleep(30)

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "mrva-agent"})

@app.route('/')
def root():
    return jsonify({"service": "mrva-agent", "version": os.environ.get("VERSION", "test")})

if __name__ == '__main__':
    # Start worker thread
    t = threading.Thread(target=worker, daemon=True)
    t.start()
    app.run(host='0.0.0.0', port=8071)
EOF

docker build -t "mrva-agent:$TAG" -f "$TEMP_DIR/Dockerfile.agent" "$TEMP_DIR"
log_success "Built mrva-agent:$TAG"

# =============================================================================
# mrva-hepc-container - HEPC endpoint
# =============================================================================
log_info "Building mrva-hepc-container:$TAG (test image)..."
cat > "$TEMP_DIR/Dockerfile.hepc" << 'EOF'
FROM python:3.11-alpine
RUN pip install flask
WORKDIR /app
COPY hepc.py .
EXPOSE 8070
CMD ["python", "hepc.py"]
EOF

cat > "$TEMP_DIR/hepc.py" << 'EOF'
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "hepc"})

@app.route('/')
def root():
    return jsonify({"service": "hepc", "version": os.environ.get("VERSION", "test")})

if __name__ == '__main__':
    print("[hepc] Starting HEPC service on port 8070...")
    app.run(host='0.0.0.0', port=8070)
EOF

docker build -t "mrva-hepc-container:$TAG" -f "$TEMP_DIR/Dockerfile.hepc" "$TEMP_DIR"
log_success "Built mrva-hepc-container:$TAG"

# =============================================================================
# Load images to minikube if requested
# =============================================================================
if [[ "$LOAD_TO_MINIKUBE" == "true" ]]; then
    log_info "Loading images into minikube..."

    for image in "mrva-server:$TAG" "mrva-agent:$TAG" "mrva-hepc-container:$TAG"; do
        log_info "Loading $image..."
        minikube image load "$image"
        log_success "Loaded $image"
    done

    log_info "Images in minikube:"
    minikube image ls | grep -E "mrva|hepc" || echo "(none found)"
fi

log_success "All test images created successfully!"
echo ""
echo "Images created:"
docker images | grep -E "mrva-server|mrva-agent|mrva-hepc" | grep "$TAG"
echo ""
echo "To load into minikube:"
echo "  minikube image load mrva-server:$TAG"
echo "  minikube image load mrva-agent:$TAG"
echo "  minikube image load mrva-hepc-container:$TAG"
echo ""
echo "Or run this script with --load flag"
