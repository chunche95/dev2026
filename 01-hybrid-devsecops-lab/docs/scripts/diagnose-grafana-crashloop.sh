#!/bin/bash
################################################################################
# Script: diagnose-grafana-crashloop.sh
# Purpose: Diagnose Grafana CrashLoopBackOff and collect all diagnostic data
# Author: Platform Engineering Team
# Date: 2026-01-18
# Reference: docs/incidents/INC-2026-01-18-grafana-crashloop.md
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
NAMESPACE="monitoring"
OUTPUT_DIR="$HOME/cluster-audit/observability"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DIAGNOSTICS_DIR="$OUTPUT_DIR/diagnostics-$TIMESTAMP"

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

log_section() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"
}

create_output_directory() {
    log_info "Creating diagnostics directory: $DIAGNOSTICS_DIR"
    mkdir -p "$DIAGNOSTICS_DIR"
}

collect_pod_status() {
    log_section "1. Collecting Pod Status"
    
    log_info "Getting all pods in monitoring namespace..."
    kubectl get pods -n "$NAMESPACE" -o wide > "$DIAGNOSTICS_DIR/pods-list.txt"
    
    log_info "Getting Grafana pod details..."
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o yaml \
        > "$DIAGNOSTICS_DIR/grafana-pod-full.yaml"
    
    log_info "Describing Grafana pod..."
    GRAFANA_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$GRAFANA_POD" ]; then
        kubectl describe pod -n "$NAMESPACE" "$GRAFANA_POD" \
            > "$DIAGNOSTICS_DIR/grafana-pod-describe.txt"
        log_info "Pod: $GRAFANA_POD"
    else
        log_warn "No Grafana pod found"
    fi
}

collect_pod_logs() {
    log_section "2. Collecting Pod Logs"
    
    GRAFANA_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$GRAFANA_POD" ]; then
        log_warn "No Grafana pod found, skipping logs"
        return
    fi
    
    # Current logs
    log_info "Collecting current logs (grafana container)..."
    kubectl logs -n "$NAMESPACE" "$GRAFANA_POD" -c grafana --tail=500 \
        > "$DIAGNOSTICS_DIR/grafana-logs-current.txt" 2>&1 || true
    
    # Previous logs (if pod crashed)
    log_info "Collecting previous logs (if available)..."
    kubectl logs -n "$NAMESPACE" "$GRAFANA_POD" -c grafana --previous --tail=500 \
        > "$DIAGNOSTICS_DIR/grafana-logs-previous.txt" 2>&1 || true
    
    # Sidecar logs
    log_info "Collecting sidecar container logs..."
    kubectl logs -n "$NAMESPACE" "$GRAFANA_POD" -c grafana-sc-dashboard --tail=200 \
        > "$DIAGNOSTICS_DIR/grafana-sc-dashboard-logs.txt" 2>&1 || true
    kubectl logs -n "$NAMESPACE" "$GRAFANA_POD" -c grafana-sc-datasources --tail=200 \
        > "$DIAGNOSTICS_DIR/grafana-sc-datasources-logs.txt" 2>&1 || true
}

collect_configmaps() {
    log_section "3. Collecting ConfigMaps"
    
    log_info "Listing all Grafana-related ConfigMaps..."
    kubectl get cm -n "$NAMESPACE" -l grafana_datasource=1 \
        > "$DIAGNOSTICS_DIR/configmaps-list.txt" 2>&1 || true
    
    log_info "Exporting Loki datasource ConfigMap..."
    kubectl get cm -n "$NAMESPACE" loki-loki-stack -o yaml \
        > "$DIAGNOSTICS_DIR/cm-loki-datasource.yaml" 2>&1 || true
    
    log_info "Exporting Prometheus datasource ConfigMap..."
    kubectl get cm -n "$NAMESPACE" monitorgrafana-kube-promet-grafana-datasource -o yaml \
        > "$DIAGNOSTICS_DIR/cm-prometheus-datasource.yaml" 2>&1 || true
    
    log_info "Checking isDefault values..."
    {
        echo "=== Loki Datasource ==="
        kubectl get cm -n "$NAMESPACE" loki-loki-stack -o yaml | grep -A 5 "isDefault" || echo "Not found"
        echo ""
        echo "=== Prometheus Datasource ==="
        kubectl get cm -n "$NAMESPACE" monitorgrafana-kube-promet-grafana-datasource -o yaml | grep -A 5 "isDefault" || echo "Not found"
    } > "$DIAGNOSTICS_DIR/datasource-isDefault-check.txt"
}

collect_deployment_info() {
    log_section "4. Collecting Deployment Info"
    
    log_info "Getting Grafana deployment..."
    kubectl get deployment -n "$NAMESPACE" monitorgrafana -o yaml \
        > "$DIAGNOSTICS_DIR/grafana-deployment.yaml" 2>&1 || true
    
    log_info "Describing Grafana deployment..."
    kubectl describe deployment -n "$NAMESPACE" monitorgrafana \
        > "$DIAGNOSTICS_DIR/grafana-deployment-describe.txt" 2>&1 || true
    
    log_info "Getting ReplicaSet info..."
    kubectl get rs -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o wide \
        > "$DIAGNOSTICS_DIR/grafana-replicasets.txt" 2>&1 || true
}

collect_events() {
    log_section "5. Collecting Events"
    
    log_info "Getting recent events in monitoring namespace..."
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' \
        > "$DIAGNOSTICS_DIR/events-recent.txt" 2>&1 || true
    
    log_info "Filtering Grafana-related events..."
    kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$GRAFANA_POD" \
        > "$DIAGNOSTICS_DIR/events-grafana-pod.txt" 2>&1 || true
}

collect_services() {
    log_section "6. Collecting Service Info"
    
    log_info "Getting Grafana service..."
    kubectl get svc -n "$NAMESPACE" monitorgrafana -o yaml \
        > "$DIAGNOSTICS_DIR/grafana-service.yaml" 2>&1 || true
    
    log_info "Getting all monitoring services..."
    kubectl get svc -n "$NAMESPACE" -o wide \
        > "$DIAGNOSTICS_DIR/services-list.txt" 2>&1 || true
}

analyze_root_cause() {
    log_section "7. Analyzing Root Cause"
    
    log_info "Analyzing logs for common errors..."
    
    {
        echo "=== Searching for 'error' in logs ==="
        grep -i "error" "$DIAGNOSTICS_DIR/grafana-logs-current.txt" | head -20 || echo "No errors found"
        
        echo ""
        echo "=== Searching for 'failed' in logs ==="
        grep -i "failed" "$DIAGNOSTICS_DIR/grafana-logs-current.txt" | head -20 || echo "No failures found"
        
        echo ""
        echo "=== Searching for 'datasource' in logs ==="
        grep -i "datasource" "$DIAGNOSTICS_DIR/grafana-logs-current.txt" | head -30 || echo "No datasource mentions"
        
        echo ""
        echo "=== Checking restart count ==="
        kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
            -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].restartCount}{"\n"}{end}'
    } > "$DIAGNOSTICS_DIR/analysis-errors.txt"
}

test_http_endpoint() {
    log_section "8. Testing HTTP Endpoint"
    
    log_info "Testing Grafana NodePort endpoint..."
    
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
    NODEPORT=$(kubectl get svc -n "$NAMESPACE" monitorgrafana -o jsonpath='{.spec.ports[0].nodePort}')
    
    {
        echo "Node IP: $NODE_IP"
        echo "NodePort: $NODEPORT"
        echo "Full URL: http://$NODE_IP:$NODEPORT"
        echo ""
        echo "=== HTTP Response ==="
        curl -I "http://$NODE_IP:$NODEPORT" 2>&1 || echo "Connection failed"
    } > "$DIAGNOSTICS_DIR/http-endpoint-test.txt"
}

generate_summary() {
    log_section "9. Generating Summary Report"
    
    GRAFANA_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "NOT_FOUND")
    
    POD_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "UNKNOWN")
    
    RESTART_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
    
    LOKI_DEFAULT=$(grep "isDefault" "$DIAGNOSTICS_DIR/cm-loki-datasource.yaml" 2>/dev/null | awk '{print $2}' || echo "UNKNOWN")
    PROM_DEFAULT=$(grep "isDefault" "$DIAGNOSTICS_DIR/cm-prometheus-datasource.yaml" 2>/dev/null | awk '{print $2}' || echo "UNKNOWN")
    
    cat > "$DIAGNOSTICS_DIR/SUMMARY.txt" << EOF
╔════════════════════════════════════════════════════════════════════════╗
║                    GRAFANA DIAGNOSTICS SUMMARY                         ║
╚════════════════════════════════════════════════════════════════════════╝

Date: $(date)
Namespace: $NAMESPACE
Output Directory: $DIAGNOSTICS_DIR

════════════════════════════════════════════════════════════════════════
POD STATUS
════════════════════════════════════════════════════════════════════════
Pod Name: $GRAFANA_POD
Status: $POD_STATUS
Restart Count: $RESTART_COUNT

════════════════════════════════════════════════════════════════════════
DATASOURCE CONFIGURATION
════════════════════════════════════════════════════════════════════════
Loki isDefault: $LOKI_DEFAULT
Prometheus isDefault: $PROM_DEFAULT

$(if [ "$LOKI_DEFAULT" = "true" ] && [ "$PROM_DEFAULT" = "true" ]; then
    echo "⚠️  PROBLEM DETECTED: Multiple datasources marked as default!"
    echo "    This will cause Grafana to crash."
else
    echo "✅ Datasource configuration appears correct"
fi)

════════════════════════════════════════════════════════════════════════
COLLECTED FILES
════════════════════════════════════════════════════════════════════════
EOF
    
    ls -lh "$DIAGNOSTICS_DIR" >> "$DIAGNOSTICS_DIR/SUMMARY.txt"
    
    cat >> "$DIAGNOSTICS_DIR/SUMMARY.txt" << EOF

════════════════════════════════════════════════════════════════════════
NEXT STEPS
════════════════════════════════════════════════════════════════════════
1. Review SUMMARY.txt (this file)
2. Check analysis-errors.txt for error patterns
3. Review grafana-logs-current.txt for detailed logs
4. If datasource conflict detected, run:
   ./fix-grafana-datasource-conflict.sh

════════════════════════════════════════════════════════════════════════
REFERENCES
════════════════════════════════════════════════════════════════════════
Incident: docs/incidents/INC-2026-01-18-grafana-crashloop.md
Runbook: docs/runbooks/RB-001-grafana-datasource-conflict.md
EOF
}

print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                    DIAGNOSTICS COMPLETE                                ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Diagnostics saved to:"
    echo "  $DIAGNOSTICS_DIR"
    echo ""
    echo "Key files:"
    echo "  📋 SUMMARY.txt                    - Quick overview"
    echo "  📝 grafana-logs-current.txt       - Current pod logs"
    echo "  🔍 analysis-errors.txt            - Error analysis"
    echo "  ⚙️  cm-*-datasource.yaml          - Datasource configs"
    echo ""
    echo "Next steps:"
    echo "  1. Review: cat $DIAGNOSTICS_DIR/SUMMARY.txt"
    echo "  2. If datasource conflict, run: ./fix-grafana-datasource-conflict.sh"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║           Grafana CrashLoopBackOff Diagnostic Tool                    ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    create_output_directory
    collect_pod_status
    collect_pod_logs
    collect_configmaps
    collect_deployment_info
    collect_events
    collect_services
    analyze_root_cause
    test_http_endpoint
    generate_summary
    
    print_summary
}

# Execute
main
