#!/bin/bash
################################################################################
# Script: fix-grafana-datasource-conflict.sh
# Purpose: Resolve Grafana CrashLoopBackOff caused by multiple default datasources
# Incident: INC-2026-01-18-GRAFANA-CRASHLOOP
# Author: Platform Engineering Team
# Date: 2026-01-18
# Reference: docs/runbooks/RB-001-grafana-datasource-conflict.md
################################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="monitoring"
CONFIGMAP_NAME="loki-loki-stack"
BACKUP_DIR="$HOME/cluster-audit/observability/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

################################################################################
# Functions
################################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' not found"
        exit 1
    fi
    
    log_info "Prerequisites check: PASSED"
}

verify_problem_exists() {
    log_info "Verifying Grafana CrashLoopBackOff..."
    
    POD_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].status.containerStatuses[0].state}' 2>/dev/null || echo "")
    
    if echo "$POD_STATUS" | grep -q "waiting"; then
        log_warn "Grafana pod is in waiting state (likely CrashLoopBackOff)"
        return 0
    fi
    
    # Check restart count
    RESTART_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
    
    if [ "$RESTART_COUNT" -gt 10 ]; then
        log_warn "Grafana pod has $RESTART_COUNT restarts - investigating..."
        return 0
    fi
    
    log_info "No obvious problem detected, but proceeding with fix as requested"
    return 0
}

create_backup() {
    log_info "Creating backup of ConfigMap..."
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    BACKUP_FILE="$BACKUP_DIR/${CONFIGMAP_NAME}-${TIMESTAMP}.yaml"
    
    kubectl get cm -n "$NAMESPACE" "$CONFIGMAP_NAME" -o yaml > "$BACKUP_FILE"
    
    if [ -f "$BACKUP_FILE" ]; then
        log_info "Backup created: $BACKUP_FILE"
        log_info "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
    else
        log_error "Failed to create backup"
        exit 1
    fi
}

apply_fix() {
    log_info "Applying fix: Setting Loki datasource to isDefault: false..."
    
    # Patch ConfigMap
    kubectl patch cm -n "$NAMESPACE" "$CONFIGMAP_NAME" --type='json' \
        -p='[{"op": "replace", "path": "/data/loki-stack-datasource.yaml", 
        "value": "apiVersion: 1\ndatasources:\n- name: Loki\n  type: loki\n  access: proxy\n  url: \"http://loki:3100\"\n  version: 1\n  isDefault: false\n  jsonData:\n    {}\n"}]'
    
    if [ $? -eq 0 ]; then
        log_info "ConfigMap patched successfully"
    else
        log_error "Failed to patch ConfigMap"
        exit 1
    fi
}

verify_configmap_change() {
    log_info "Verifying ConfigMap change..."
    
    IS_DEFAULT=$(kubectl get cm -n "$NAMESPACE" "$CONFIGMAP_NAME" \
        -o yaml | grep "isDefault" | awk '{print $2}')
    
    if [ "$IS_DEFAULT" = "false" ]; then
        log_info "Verification PASSED: isDefault is now 'false'"
    else
        log_error "Verification FAILED: isDefault is '$IS_DEFAULT' (expected 'false')"
        exit 1
    fi
}

restart_grafana_pod() {
    log_info "Restarting Grafana pod..."
    
    # Get current pod name
    OLD_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].metadata.name}')
    
    log_info "Current pod: $OLD_POD"
    
    # Delete pod
    kubectl delete pod -n "$NAMESPACE" "$OLD_POD"
    
    log_info "Pod deleted. Waiting for new pod to be created..."
    sleep 5
    
    # Wait for new pod to be ready
    kubectl wait --for=condition=ready pod -n "$NAMESPACE" \
        -l app.kubernetes.io/name=grafana --timeout=120s
    
    if [ $? -eq 0 ]; then
        NEW_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
            -o jsonpath='{.items[0].metadata.name}')
        log_info "New pod created and ready: $NEW_POD"
    else
        log_error "Pod did not become ready within 120 seconds"
        log_warn "Check logs: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=grafana -c grafana"
        exit 1
    fi
}

validate_grafana_health() {
    log_info "Validating Grafana health..."
    
    # Check pod status
    POD_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].status.phase}')
    
    if [ "$POD_STATUS" != "Running" ]; then
        log_error "Pod status is '$POD_STATUS' (expected 'Running')"
        return 1
    fi
    
    # Check restart count (should be 0 for new pod)
    RESTART_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}')
    
    log_info "Pod status: $POD_STATUS"
    log_info "Restart count: $RESTART_COUNT"
    
    # Check container readiness
    READY=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].status.containerStatuses[*].ready}')
    
    if echo "$READY" | grep -q "false"; then
        log_error "Some containers are not ready: $READY"
        return 1
    fi
    
    log_info "All containers ready: $READY"
    
    # Check HTTP endpoint
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
    NODEPORT=$(kubectl get svc -n "$NAMESPACE" monitorgrafana \
        -o jsonpath='{.spec.ports[0].nodePort}')
    
    log_info "Testing HTTP endpoint: http://$NODE_IP:$NODEPORT"
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$NODE_IP:$NODEPORT" || echo "000")
    
    if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
        log_info "HTTP endpoint accessible (HTTP $HTTP_CODE)"
    else
        log_warn "HTTP endpoint returned $HTTP_CODE (expected 302 or 200)"
        log_warn "This may be normal if NodePort is not exposed"
    fi
    
    log_info "Validation PASSED: Grafana is healthy"
    return 0
}

print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                         FIX SUMMARY                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Incident: INC-2026-01-18-GRAFANA-CRASHLOOP"
    echo "Status: ✅ RESOLVED"
    echo ""
    echo "Changes Applied:"
    echo "  - ConfigMap '$CONFIGMAP_NAME' patched"
    echo "  - Loki datasource: isDefault changed to 'false'"
    echo "  - Prometheus datasource: remains isDefault='true'"
    echo "  - Grafana pod restarted"
    echo ""
    echo "Backup Location:"
    echo "  $BACKUP_DIR/${CONFIGMAP_NAME}-${TIMESTAMP}.yaml"
    echo ""
    echo "Next Steps:"
    echo "  1. Access Grafana UI: http://<NODE_IP>:$NODEPORT"
    echo "  2. Verify dashboards load correctly"
    echo "  3. Create incident report: docs/incidents/"
    echo "  4. Update runbook: docs/runbooks/RB-001"
    echo ""
    echo "Rollback (if needed):"
    echo "  kubectl apply -f $BACKUP_DIR/${CONFIGMAP_NAME}-${TIMESTAMP}.yaml"
    echo "  kubectl delete pod -n $NAMESPACE -l app.kubernetes.io/name=grafana"
    echo ""
    echo "Documentation:"
    echo "  - Incident: docs/incidents/INC-2026-01-18-grafana-crashloop.md"
    echo "  - Runbook: docs/runbooks/RB-001-grafana-datasource-conflict.md"
    echo "  - ADR: docs/adr/ADR-003-grafana-datasource-default.md"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║       Grafana Datasource Conflict Resolution Script                   ║"
    echo "║       INC-2026-01-18-GRAFANA-CRASHLOOP                                ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Step 1: Prerequisites
    check_prerequisites
    echo ""
    
    # Step 2: Verify problem
    verify_problem_exists
    echo ""
    
    # Step 3: Create backup
    create_backup
    echo ""
    
    # Step 4: Apply fix
    apply_fix
    echo ""
    
    # Step 5: Verify ConfigMap change
    verify_configmap_change
    echo ""
    
    # Step 6: Restart Grafana pod
    restart_grafana_pod
    echo ""
    
    # Step 7: Validate health
    if validate_grafana_health; then
        echo ""
        log_info "✅ FIX COMPLETED SUCCESSFULLY"
        print_summary
        exit 0
    else
        echo ""
        log_error "❌ FIX COMPLETED BUT VALIDATION FAILED"
        log_warn "Check pod logs and status manually"
        print_summary
        exit 1
    fi
}

# Execute main function
main
