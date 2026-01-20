#!/bin/bash
# =============================================================================
# test-docker-builds.sh
# Test Docker image builds locally to catch errors before CI
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Parse arguments
IMAGES="${1:-all}"
CREATE_STUBS="${CREATE_STUBS:-false}"

usage() {
    echo "Usage: $0 [server|agent|hepc|ghmrva|all]"
    echo ""
    echo "Environment variables:"
    echo "  CREATE_STUBS=true  Create stub binaries for testing (default: false)"
    echo ""
    echo "Examples:"
    echo "  $0 server           # Build only server image"
    echo "  $0 all              # Build all images"
    echo "  CREATE_STUBS=true $0 server  # Build server with stub binary"
    exit 1
}

create_stub_binary() {
    local name=$1
    local path=$2
    
    log_warn "Creating stub binary for $name at $path"
    cat > "$path" << 'EOF'
#!/bin/sh
echo "Stub binary - for testing only"
echo "This would be the actual $name binary in production"
exit 0
EOF
    chmod +x "$path"
}

build_server() {
    log_info "Building server image..."
    cd "$ROOT_DIR/containers/server"
    
    # Check if binary exists
    if [[ ! -f "mrvaserver" ]]; then
        if [[ "$CREATE_STUBS" == "true" ]]; then
            create_stub_binary "mrvaserver" "mrvaserver"
        else
            log_error "mrvaserver binary not found!"
            log_info "Either:"
            log_info "  1. Build the binary from the mrvaserver repo"
            log_info "  2. Run with CREATE_STUBS=true for testing"
            return 1
        fi
    fi
    
    docker build -t test-codeql-mrva-server:local .
    log_info "Server image built successfully"
}

build_agent() {
    log_info "Building agent image..."
    cd "$ROOT_DIR/containers/agent"
    
    # Check if binary exists
    if [[ ! -f "mrvaagent" ]]; then
        if [[ "$CREATE_STUBS" == "true" ]]; then
            create_stub_binary "mrvaagent" "mrvaagent"
        else
            log_error "mrvaagent binary not found!"
            log_info "Either:"
            log_info "  1. Build the binary from the mrvaagent repo"
            log_info "  2. Run with CREATE_STUBS=true for testing"
            return 1
        fi
    fi
    
    docker build -t test-codeql-mrva-agent:local .
    log_info "Agent image built successfully"
}

build_hepc() {
    log_info "Building HEPC image..."
    cd "$ROOT_DIR/containers/hepc"
    
    # Check if submodule exists
    if [[ ! -d "mrva-go-hepc" ]] && [[ ! -d "mrvahepc" ]]; then
        log_warn "HEPC submodule not found, checking if Dockerfile expects local mrvahepc/"
        # The Dockerfile expects mrvahepc directory
        if [[ ! -d "mrvahepc" ]]; then
            log_error "Neither mrva-go-hepc nor mrvahepc directory found!"
            log_info "Clone the mrva-go-hepc repository or create mrvahepc directory"
            return 1
        fi
    fi
    
    docker build -t test-codeql-mrva-hepc:local .
    log_info "HEPC image built successfully"
}

build_ghmrva() {
    log_info "Building gh-mrva image..."
    cd "$ROOT_DIR/containers/ghmrva"
    
    # Check if binary exists
    if [[ ! -f "gh-mrva" ]]; then
        if [[ "$CREATE_STUBS" == "true" ]]; then
            create_stub_binary "gh-mrva" "gh-mrva"
        else
            log_error "gh-mrva binary not found!"
            log_info "Either:"
            log_info "  1. Build the binary from the gh-mrva repo"
            log_info "  2. Run with CREATE_STUBS=true for testing"
            return 1
        fi
    fi
    
    docker build -t test-codeql-mrva-ghmrva:local .
    log_info "gh-mrva image built successfully"
}

cleanup_stubs() {
    if [[ "$CREATE_STUBS" == "true" ]]; then
        log_info "Cleaning up stub binaries..."
        rm -f "$ROOT_DIR/containers/server/mrvaserver"
        rm -f "$ROOT_DIR/containers/agent/mrvaagent"
        rm -f "$ROOT_DIR/containers/ghmrva/gh-mrva"
    fi
}

# Trap to cleanup on exit
trap cleanup_stubs EXIT

# Main
case "$IMAGES" in
    server)
        build_server
        ;;
    agent)
        build_agent
        ;;
    hepc)
        build_hepc
        ;;
    ghmrva)
        build_ghmrva
        ;;
    all)
        build_server || log_warn "Server build failed"
        build_agent || log_warn "Agent build failed"
        build_hepc || log_warn "HEPC build failed"
        build_ghmrva || log_warn "gh-mrva build failed"
        ;;
    -h|--help)
        usage
        ;;
    *)
        log_error "Unknown image: $IMAGES"
        usage
        ;;
esac

log_info "Build test complete!"
