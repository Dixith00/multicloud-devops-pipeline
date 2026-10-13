#!/usr/bin/env bash
# ==============================================================================
# Multi-Cloud DevOps Pipeline: Local Automation & Validation Script
# Automates testing, code quality checks, container builds, and IaC validation
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# UI Formatting Helpers
# ------------------------------------------------------------------------------
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}   Multi-Cloud DevOps Pipeline - Local Verification Suite       ${NC}"
echo -e "${BLUE}================================================================${NC}"

# ------------------------------------------------------------------------------
# Step 1: Environment & Tooling Verification
# ------------------------------------------------------------------------------
log_info "Step 1/5: Checking local environment dependencies..."

PYTHON_BIN=""
for candidate in python3 python py; do
    if command -v "$candidate" &>/dev/null && "$candidate" -c "import sys; print(sys.version)" &>/dev/null; then
        PYTHON_BIN="$candidate"
        break
    fi
done

if [ -z "$PYTHON_BIN" ]; then
    log_error "Python 3.11+ is not found or executable. Please ensure Python is in your PATH."
    exit 1
fi
log_success "Found Python: $($PYTHON_BIN --version)"

# ------------------------------------------------------------------------------
# Step 2: Static Code Analysis & Linting (flake8)
# ------------------------------------------------------------------------------
log_info "Step 2/5: Executing code linting with flake8..."

if ! $PYTHON_BIN -m flake8 --version &>/dev/null; then
    log_warn "flake8 not detected; installing from requirements..."
    $PYTHON_BIN -m pip install -q -r src/requirements.txt
fi

$PYTHON_BIN -m flake8 src --count --select=E9,F63,F7,F82 --show-source --statistics
$PYTHON_BIN -m flake8 src --count --max-complexity=10 --max-line-length=120 --statistics
log_success "Flake8 linting passed with zero errors."

# ------------------------------------------------------------------------------
# Step 3: Automated Unit Testing Suite (pytest)
# ------------------------------------------------------------------------------
log_info "Step 3/5: Running unit & regression test suite via pytest..."

export PYTHONPATH="${ROOT_DIR}/src:${PYTHONPATH:-}"
$PYTHON_BIN -m pytest src/tests -v
log_success "All pytest unit test assertions passed."

# ------------------------------------------------------------------------------
# Step 4: Docker Container Build & Local Probe Verification
# ------------------------------------------------------------------------------
log_info "Step 4/5: Verifying container image build and health probes..."

if command -v docker &>/dev/null && docker info &>/dev/null; then
    IMAGE_TAG="multicloud-pipeline:local-test"
    CONTAINER_NAME="multicloud-pipeline-test-runner"

    log_info "Building multi-stage Docker container..."
    docker build -t "${IMAGE_TAG}" -f src/Dockerfile src/

    log_info "Spinning up temporary test container on port 8080..."
    # Ensure any stale container is cleaned up
    docker rm -f "${CONTAINER_NAME}" &>/dev/null || true
    docker run -d --name "${CONTAINER_NAME}" -p 8080:8080 \
        -e CLOUD_PROVIDER="local-docker" \
        -e REGION="dev-box" \
        "${IMAGE_TAG}"

    log_info "Waiting for container health check readiness..."
    sleep 3

    if command -v curl &>/dev/null; then
        log_info "Testing GET http://localhost:8080/ ..."
        curl -s -f http://localhost:8080/ | grep -q "multicloud-devops-pipeline"
        log_success "Root endpoint verified."

        log_info "Testing GET http://localhost:8080/health ..."
        curl -s -f http://localhost:8080/health | grep -q "healthy"
        log_success "Health probe endpoint verified."

        log_info "Testing GET http://localhost:8080/version ..."
        curl -s -f http://localhost:8080/version | grep -q "1.0.0"
        log_success "Version metadata endpoint verified."
    else
        log_warn "curl not found, skipping container HTTP probes."
    fi

    log_info "Cleaning up temporary test container..."
    docker stop "${CONTAINER_NAME}" >/dev/null
    docker rm "${CONTAINER_NAME}" >/dev/null
    log_success "Docker container build, execution, and cleanup passed."
else
    log_warn "Docker daemon not running or not found. Testing application directly via Python WSGI mock..."
    $PYTHON_BIN -c "
import os
import sys
sys.path.insert(0, 'src')
import urllib.request
import threading
import time
from app import create_app

app = create_app()
server = threading.Thread(target=lambda: app.run(port=8089, host='127.0.0.1', use_reloader=False))
server.daemon = True
server.start()
time.sleep(1)

with urllib.request.urlopen('http://127.0.0.1:8089/') as res:
    assert res.getcode() == 200, 'Root status check failed'
with urllib.request.urlopen('http://127.0.0.1:8089/health') as res:
    assert res.getcode() == 200, 'Health status check failed'
with urllib.request.urlopen('http://127.0.0.1:8089/version') as res:
    assert res.getcode() == 200, 'Version status check failed'
print('WSGI direct application probes verified successfully!')
"
    log_success "Direct application execution verified."
fi

# ------------------------------------------------------------------------------
# Step 5: Terraform Infrastructure as Code Syntax Validation
# ------------------------------------------------------------------------------
log_info "Step 5/5: Validating Terraform configuration syntax..."

if command -v terraform &>/dev/null; then
    (
        cd terraform
        terraform fmt -check
        terraform init -backend=false
        terraform validate
    )
    log_success "Terraform configuration is valid."
else
    log_warn "Terraform CLI not found on PATH. Executing AST validation via python-hcl2..."
    $PYTHON_BIN -c "
import hcl2, glob, sys
for f in glob.glob('terraform/*.tf'):
    with open(f, 'r') as fp:
        try:
            hcl2.load(fp)
        except Exception as e:
            print(f'Error parsing {f}: {e}')
            sys.exit(1)
print('All Terraform .tf files verified syntactically valid via HCL2 parser.')
"
    log_success "HCL2 AST validation completed successfully."
fi

echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  All Verification Steps Completed Successfully! Ready to Push. ${NC}"
echo -e "${GREEN}================================================================${NC}"
