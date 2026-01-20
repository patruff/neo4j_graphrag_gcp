#!/usr/bin/env bash
set -euo pipefail

#############################################################################
# Neo4j GraphRAG GCP Deployment & Test Script
#
# This script:
# 1. Deploys Neo4j to GCP using Terraform (Always Free Tier)
# 2. Waits for Neo4j to be ready
# 3. Runs the GraphRAG round-trip test against the deployed instance
# 4. Optionally tears down the infrastructure
#
# Usage:
#   ./deploy_and_test.sh              # Deploy, test, and keep infrastructure
#   ./deploy_and_test.sh --destroy    # Deploy, test, and destroy
#   ./deploy_and_test.sh --skip-test  # Deploy only (skip test)
#
# Required Environment Variables:
#   GCP_PROJECT_ID    - Your GCP project ID
#   NEO4J_PASSWORD    - Password for Neo4j (min 8 chars)
#
# Optional:
#   ALLOWED_IP        - Your IP in CIDR format (auto-detected if not set)
#   TF_VAR_region     - GCP region (default: us-central1)
#   TF_VAR_zone       - GCP zone (default: us-central1-a)
#
#############################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
DESTROY_AFTER_TEST=false
SKIP_TEST=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --destroy)
      DESTROY_AFTER_TEST=true
      shift
      ;;
    --skip-test)
      SKIP_TEST=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check required environment variables
check_env_vars() {
    local missing_vars=()

    if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
        missing_vars+=("GCP_PROJECT_ID")
    fi

    if [[ -z "${NEO4J_PASSWORD:-}" ]]; then
        missing_vars+=("NEO4J_PASSWORD")
    fi

    if [[ ${#missing_vars[@]} -ne 0 ]]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Example usage:"
        echo "  export GCP_PROJECT_ID='my-gcp-project'"
        echo "  export NEO4J_PASSWORD='SecurePassword123'"
        echo "  ./deploy_and_test.sh"
        exit 1
    fi
}

# Auto-detect allowed IP if not set
detect_allowed_ip() {
    if [[ -z "${ALLOWED_IP:-}" ]]; then
        log_info "Auto-detecting your public IP address..."

        # Try multiple services for reliability
        local detected_ip=""
        for service in "ifconfig.me" "icanhazip.com" "ipinfo.io/ip"; do
            if detected_ip=$(curl -s --max-time 5 "https://$service" 2>/dev/null); then
                # Validate IP format (basic check)
                if [[ $detected_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    ALLOWED_IP="${detected_ip}/32"
                    log_success "Auto-detected IP: $ALLOWED_IP"
                    return 0
                fi
            fi
        done

        log_error "Failed to auto-detect IP address. Please set ALLOWED_IP manually:"
        echo "  export ALLOWED_IP='1.2.3.4/32'"
        exit 1
    else
        log_info "Using provided ALLOWED_IP: $ALLOWED_IP"
    fi
}

# Check if gcloud is authenticated
check_gcloud_auth() {
    log_info "Checking gcloud authentication..."

    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "Not authenticated with gcloud. Please run:"
        echo "  gcloud auth application-default login"
        exit 1
    fi

    log_success "gcloud authenticated"
}

# Check if Terraform is installed
check_terraform() {
    log_info "Checking Terraform installation..."

    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found. Please install Terraform >= 1.5.0"
        echo "  https://www.terraform.io/downloads"
        exit 1
    fi

    local tf_version=$(terraform version -json | jq -r '.terraform_version')
    log_success "Terraform $tf_version found"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    log_info "Deploying infrastructure to GCP..."

    cd terraform

    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init -upgrade > /dev/null

    # Plan
    log_info "Creating Terraform plan..."
    terraform plan \
        -var="project_id=${GCP_PROJECT_ID}" \
        -var="allowed_ip=${ALLOWED_IP}" \
        -var="neo4j_password=${NEO4J_PASSWORD}" \
        -var="region=${TF_VAR_region:-us-central1}" \
        -var="zone=${TF_VAR_zone:-us-central1-a}" \
        -out=tfplan

    # Apply
    log_info "Applying Terraform configuration..."
    terraform apply -auto-approve tfplan

    log_success "Infrastructure deployed"

    cd ..
}

# Get Neo4j connection details from Terraform
get_neo4j_info() {
    cd terraform

    NEO4J_IP=$(terraform output -raw instance_public_ip)
    NEO4J_URI="bolt://${NEO4J_IP}:7687"
    NEO4J_HTTP="http://${NEO4J_IP}:7474"

    cd ..

    log_success "Neo4j connection details:"
    echo "  URI:  $NEO4J_URI"
    echo "  HTTP: $NEO4J_HTTP"
}

# Wait for Neo4j to be ready
wait_for_neo4j() {
    local max_attempts=60
    local attempt=0

    log_info "Waiting for Neo4j to be ready at $NEO4J_HTTP..."

    while [[ $attempt -lt $max_attempts ]]; do
        if curl -f -s "$NEO4J_HTTP" > /dev/null 2>&1; then
            log_success "Neo4j is ready!"
            return 0
        fi

        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done

    echo ""
    log_error "Neo4j did not become ready within $(($max_attempts * 5)) seconds"
    return 1
}

# Run GraphRAG test
run_test() {
    log_info "Running GraphRAG round-trip test..."

    cd src

    # Install dependencies if needed
    if ! python -c "import neo4j" 2>/dev/null; then
        log_info "Installing Python dependencies..."
        pip install -q -r requirements.txt
    fi

    # Run test
    export NEO4J_URI="$NEO4J_URI"
    export NEO4J_USER="neo4j"
    export NEO4J_PASSWORD="$NEO4J_PASSWORD"
    export TEST_RESULTS_FILE="../test_results_gcp.md"

    if python rag_test.py; then
        log_success "GraphRAG test passed!"
        echo ""
        cat ../test_results_gcp.md
        cd ..
        return 0
    else
        log_error "GraphRAG test failed"
        cd ..
        return 1
    fi
}

# Destroy infrastructure
destroy_infrastructure() {
    log_warning "Destroying infrastructure..."

    cd terraform

    terraform destroy \
        -var="project_id=${GCP_PROJECT_ID}" \
        -var="allowed_ip=${ALLOWED_IP}" \
        -var="neo4j_password=${NEO4J_PASSWORD}" \
        -var="region=${TF_VAR_region:-us-central1}" \
        -var="zone=${TF_VAR_zone:-us-central1-a}" \
        -auto-approve

    log_success "Infrastructure destroyed"

    cd ..
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "Neo4j GraphRAG GCP Deployment & Test"
    echo "=========================================="
    echo ""

    # Preflight checks
    check_env_vars
    detect_allowed_ip
    check_gcloud_auth
    check_terraform

    # Deploy
    deploy_infrastructure
    get_neo4j_info

    # Wait for Neo4j
    if ! wait_for_neo4j; then
        log_error "Deployment failed: Neo4j not ready"
        exit 1
    fi

    # Test (unless skipped)
    if [[ "$SKIP_TEST" == false ]]; then
        if ! run_test; then
            log_error "Test failed"

            if [[ "$DESTROY_AFTER_TEST" == true ]]; then
                destroy_infrastructure
            fi

            exit 1
        fi
    else
        log_info "Skipping test (--skip-test flag set)"
    fi

    # Destroy (if requested)
    if [[ "$DESTROY_AFTER_TEST" == true ]]; then
        echo ""
        destroy_infrastructure
    else
        echo ""
        log_success "Deployment complete! Infrastructure is running."
        echo ""
        echo "Neo4j Browser: $NEO4J_HTTP"
        echo "Bolt URI:      $NEO4J_URI"
        echo "Username:      neo4j"
        echo "Password:      ****"
        echo ""
        echo "To destroy the infrastructure later, run:"
        echo "  cd terraform && terraform destroy"
        echo ""
    fi
}

# Run main function
main
