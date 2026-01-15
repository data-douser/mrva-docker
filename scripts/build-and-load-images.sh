#!/usr/bin/env bash
#
# build-and-load-images.sh
#
# Build custom MRVA container images and load them into minikube for local testing.
# This script is designed to be run from the mrva-docker repository root.
#
# Usage:
#   ./scripts/build-and-load-images.sh [options]
#
# Options:
#   --skip-build    Skip building images, only load existing images into minikube
#   --skip-load     Skip loading images into minikube, only build
#   --image NAME    Build/load only the specified image (server, agent, hepc, ghmrva, vscode)
#   --tag TAG       Use a custom tag (default: 0.4.5)
#   --help          Show this help message
#
# Prerequisites:
#   - Docker installed and running
#   - minikube installed and running
#   - Go compiler (for server/agent/ghmrva builds)
#   - Source code for mrvaserver, mrvaagent, gh-mrva, mrvahepc in sibling directories
#
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_TAG="0.4.5"
TAG="${TAG:-$DEFAULT_TAG}"

# Source directories (relative to repo root's parent)
PARENT_DIR="$(dirname "$REPO_ROOT")"
MRVA_SERVER_SRC="${MRVA_SERVER_SRC:-$PARENT_DIR/mrvaserver}"
MRVA_AGENT_SRC="${MRVA_AGENT_SRC:-$PARENT_DIR/mrvaagent}"
GH_MRVA_SRC="${GH_MRVA_SRC:-$PARENT_DIR/gh-mrva}"
MRVA_HEPC_SRC="${MRVA_HEPC_SRC:-$PARENT_DIR/mrvahepc}"

# Container directories
CONTAINERS_DIR="$REPO_ROOT/containers"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
SKIP_BUILD=false
SKIP_LOAD=false
SPECIFIC_IMAGE=""

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    head -30 "$0" | grep -E "^#" | sed 's/^# *//'
    exit 0
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi

    if ! command -v minikube &> /dev/null; then
        log_error "minikube is not installed or not in PATH"
        exit 1
    fi

    if ! minikube status &> /dev/null; then
        log_error "minikube is not running. Start it with: minikube start"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

build_server() {
    local image_name="mrva-server:$TAG"
    local cont_dir="$CONTAINERS_DIR/server"

    log_info "Building $image_name..."

    if [[ ! -d "$MRVA_SERVER_SRC" ]]; then
        log_warn "Server source directory not found: $MRVA_SERVER_SRC"
        log_warn "Skipping server build. Set MRVA_SERVER_SRC to override."
        return 1
    fi

    # Build Go binary
    log_info "Compiling mrvaserver binary..."
    (cd "$MRVA_SERVER_SRC" && go build -o mrvaserver .)

    # Copy binary to container directory
    cp "$MRVA_SERVER_SRC/mrvaserver" "$cont_dir/"

    # Build Docker image
    docker build -t "$image_name" "$cont_dir"

    log_success "Built $image_name"
}

build_agent() {
    local image_name="mrva-agent:$TAG"
    local cont_dir="$CONTAINERS_DIR/agent"

    log_info "Building $image_name..."

    if [[ ! -d "$MRVA_AGENT_SRC" ]]; then
        log_warn "Agent source directory not found: $MRVA_AGENT_SRC"
        log_warn "Skipping agent build. Set MRVA_AGENT_SRC to override."
        return 1
    fi

    # Build Go binary
    log_info "Compiling mrvaagent binary..."
    (cd "$MRVA_AGENT_SRC" && go build -o mrvaagent .)

    # Copy binary to container directory
    cp "$MRVA_AGENT_SRC/mrvaagent" "$cont_dir/"

    # Build Docker image
    docker build -t "$image_name" "$cont_dir"

    log_success "Built $image_name"
}

build_hepc() {
    local image_name="mrva-hepc-container:$TAG"
    local cont_dir="$CONTAINERS_DIR/hepc"

    log_info "Building $image_name..."

    if [[ ! -d "$MRVA_HEPC_SRC" ]]; then
        log_warn "HEPC source directory not found: $MRVA_HEPC_SRC"
        log_warn "Skipping HEPC build. Set MRVA_HEPC_SRC to override."
        return 1
    fi

    # Sync source code to container directory (excluding venv and .git)
    log_info "Syncing mrvahepc source..."
    rm -rf "$cont_dir/mrvahepc"
    rsync -a --exclude='*/venv/*' --exclude='*/.git/*' "$MRVA_HEPC_SRC" "$cont_dir/"

    # Build Docker image
    docker build -t "$image_name" -f "$cont_dir/Dockerfile" "$cont_dir"

    log_success "Built $image_name"
}

build_ghmrva() {
    local image_name="mrva-gh-mrva:$TAG"
    local cont_dir="$CONTAINERS_DIR/ghmrva"

    log_info "Building $image_name..."

    if [[ ! -d "$GH_MRVA_SRC" ]]; then
        log_warn "gh-mrva source directory not found: $GH_MRVA_SRC"
        log_warn "Skipping gh-mrva build. Set GH_MRVA_SRC to override."
        return 1
    fi

    # Build Go binary
    log_info "Compiling gh-mrva binary..."
    (cd "$GH_MRVA_SRC" && go build -o gh-mrva .)

    # Copy binary to container directory
    cp "$GH_MRVA_SRC/gh-mrva" "$cont_dir/"

    # Build Docker image
    docker build -t "$image_name" "$cont_dir"

    log_success "Built $image_name"
}

build_vscode() {
    local image_name="code-server-initialized:$TAG"
    local cont_dir="$CONTAINERS_DIR/vscode"

    log_info "Building $image_name..."

    # Build Docker image
    docker build -t "$image_name" "$cont_dir"

    log_success "Built $image_name"
}

load_image_to_minikube() {
    local image_name="$1"

    log_info "Loading $image_name into minikube..."

    # Check if image exists locally
    if ! docker image inspect "$image_name" &> /dev/null; then
        log_warn "Image $image_name not found locally, skipping load"
        return 1
    fi

    # Use minikube cache add to cache and load the image
    # This caches to $MINIKUBE_HOME/cache/images and auto-loads to cluster
    minikube cache add "$image_name"

    log_success "Loaded $image_name into minikube cache"
}

load_image_direct() {
    local image_name="$1"

    log_info "Loading $image_name directly into minikube..."

    # Check if image exists locally
    if ! docker image inspect "$image_name" &> /dev/null; then
        log_warn "Image $image_name not found locally, skipping load"
        return 1
    fi

    # Use minikube image load for direct loading (faster, no caching)
    minikube image load "$image_name"

    log_success "Loaded $image_name into minikube"
}

build_all() {
    log_info "Building all MRVA images with tag $TAG..."

    local failed=()

    build_server || failed+=("server")
    build_agent || failed+=("agent")
    build_hepc || failed+=("hepc")
    build_ghmrva || failed+=("ghmrva")
    build_vscode || failed+=("vscode")

    if [[ ${#failed[@]} -gt 0 ]]; then
        log_warn "Failed to build: ${failed[*]}"
    fi

    log_info "Build phase complete"
}

load_all() {
    log_info "Loading all MRVA images into minikube..."

    local images=(
        "mrva-server:$TAG"
        "mrva-agent:$TAG"
        "mrva-hepc-container:$TAG"
        "mrva-gh-mrva:$TAG"
        "code-server-initialized:$TAG"
    )

    local loaded=0
    local failed=0

    for image in "${images[@]}"; do
        if load_image_direct "$image"; then
            ((loaded++))
        else
            ((failed++))
        fi
    done

    log_info "Loaded $loaded images, failed to load $failed images"
}

verify_images() {
    log_info "Verifying images in minikube..."

    echo ""
    echo "Images in minikube matching 'mrva|hepc|code-server':"
    minikube image ls | grep -E "mrva|hepc|code-server" || echo "  (none found)"
    echo ""

    echo "Images cached by minikube:"
    minikube cache list 2>/dev/null || echo "  (cache empty or not available)"
    echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-load)
            SKIP_LOAD=true
            shift
            ;;
        --image)
            SPECIFIC_IMAGE="$2"
            shift 2
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            ;;
    esac
done

# Main execution
main() {
    echo ""
    echo "=============================================="
    echo " MRVA Container Image Build & Load Script"
    echo "=============================================="
    echo ""
    log_info "Tag: $TAG"
    log_info "Skip build: $SKIP_BUILD"
    log_info "Skip load: $SKIP_LOAD"
    [[ -n "$SPECIFIC_IMAGE" ]] && log_info "Specific image: $SPECIFIC_IMAGE"
    echo ""

    check_prerequisites

    if [[ -n "$SPECIFIC_IMAGE" ]]; then
        # Build/load specific image
        if [[ "$SKIP_BUILD" != "true" ]]; then
            case "$SPECIFIC_IMAGE" in
                server) build_server ;;
                agent) build_agent ;;
                hepc) build_hepc ;;
                ghmrva) build_ghmrva ;;
                vscode) build_vscode ;;
                *) log_error "Unknown image: $SPECIFIC_IMAGE"; exit 1 ;;
            esac
        fi

        if [[ "$SKIP_LOAD" != "true" ]]; then
            case "$SPECIFIC_IMAGE" in
                server) load_image_direct "mrva-server:$TAG" ;;
                agent) load_image_direct "mrva-agent:$TAG" ;;
                hepc) load_image_direct "mrva-hepc-container:$TAG" ;;
                ghmrva) load_image_direct "mrva-gh-mrva:$TAG" ;;
                vscode) load_image_direct "code-server-initialized:$TAG" ;;
            esac
        fi
    else
        # Build/load all images
        [[ "$SKIP_BUILD" != "true" ]] && build_all
        [[ "$SKIP_LOAD" != "true" ]] && load_all
    fi

    verify_images

    log_success "Done!"
}

main "$@"
