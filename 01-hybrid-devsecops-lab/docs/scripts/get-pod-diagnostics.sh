#!/bin/bash
################################################################################
# Script: get-pod-diagnostics.sh
# Purpose: Extract comprehensive diagnostics for a specific pod
# Usage: ./get-pod-diagnostics.sh <namespace> <pod-name> [output-dir]
# Author: Platform Engineering Team
# Date: 2026-01-18
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <namespace> <pod-name> [output-dir]"
    echo ""
    echo "Example:"
    echo "  $0 monitoring monitorgrafana-677d8d6465-tktwr"
    echo "  $0 monitoring monitorgrafana-677d8d6465-tktwr ./diagnostics"
    exit 1
fi

NAMESPACE="$1"
POD_NAME="$2"
OUTPUT_DIR="${3:-./cluster-diagnostics}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Create output directory
mkdir -p "$OUTPUT_DIR"

log_info "Starting diagnostics for pod: $POD_NAME in namespace: $NAMESPACE"
log_info "Output directory: $OUTPUT_DIR"

################################################################################
# 1. Pod Description
################################################################################
log_info "Extracting pod description..."
kubectl describe pod -n "$NAMESPACE" "$POD_NAME" \
    > "$OUTPUT_DIR/${POD_NAME}-describe.txt" 2>&1

if [ $? -eq 0 ]; then
    log_info "✓ Pod description saved: ${POD_NAME}-describe.txt"
else
    log_error "✗ Failed to get pod description"
fi

################################################################################
# 2. Pod YAML
################################################################################
log_info "Extracting pod YAML..."
kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o yaml \
    > "$OUTPUT_DIR/${POD_NAME}-yaml.yaml" 2>&1

if [ $? -eq 0 ]; then
    log_info "✓ Pod YAML saved: ${POD_NAME}-yaml.yaml"
else
    log_error "✗ Failed to get pod YAML"
fi

################################################################################
# 3. Pod Logs (All Containers)
################################################################################
log_info "Extracting logs from all containers..."

# Get container names
CONTAINERS=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" \
    -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)

if [ -n "$CONTAINERS" ]; then
    for CONTAINER in $CONTAINERS; do
        log_info "  Extracting logs from container: $CONTAINER"
        
        # Current logs
        kubectl logs -n "$NAMESPACE" "$POD_NAME" -c "$CONTAINER" --tail=500 \
            > "$OUTPUT_DIR/${POD_NAME}-${CONTAINER}-logs.txt" 2>&1
        
        # Previous logs (if pod restarted)
        kubectl logs -n "$NAMESPACE" "$POD_NAME" -c "$CONTAINER" --previous --tail=500 \
            > "$OUTPUT_DIR/${POD_NAME}-${CONTAINER}-previous-logs.txt" 2>&1 || true
        
        log_info "  ✓ Container $CONTAINER logs saved"
    done
else
    log_warn "No containers found in pod"
fi

################################################################################
# 4. Pod Events
################################################################################
log_info "Extracting pod events..."
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$POD_NAME" \
    --sort-by='.lastTimestamp' \
    > "$OUTPUT_DIR/${POD_NAME}-events.txt" 2>&1

if [ $? -eq 0 ]; then
    log_info "✓ Pod events saved: ${POD_NAME}-events.txt"
else
    log_warn "✗ No events found or failed to get events"
fi
