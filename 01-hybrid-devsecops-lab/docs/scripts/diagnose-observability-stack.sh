#!/bin/bash
################################################################################
# Script: diagnose-observability-stack.sh
# Purpose: Comprehensive diagnostics for monitoring namespace issues
# Use Case: First step when troubleshooting Grafana/Prometheus/Loki problems
# Author: Platform Engineering Team
# Date: 2026-01-18
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACE="monitoring"
OUTPUT_DIR="$HOME/cluster-audit/observability"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DIAGNOSTICS_DIR="$OUTPUT_DIR/diagnostics-$TIMESTAMP"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BLUE}==== $1 ====${NC}\n"; }

################################################################################
# Main Diagnostics
################################################################################

main() {
    log_section "Observability Stack Diagnostics"
    log_info "Creating diagnostics directory: $DIAGNOSTICS_DIR"
    mkdir -p "$DIAGNOSTICS_DIR"
    
    # 1. Pod Status
    log_section "1. Pod Status Overview"
    kubectl get pods -n "$NAMESPACE" -o wide | tee "$DIAGNOSTICS_DIR/pods-overview.txt"
    
    # 2. Identify Problematic Pods
    log_section "2. Identifying Problematic Pods"
    kubectl get pods -n "$NAMESPACE" -o json | \
        jq -r '.items[] | select(.status.containerStatuses[]?.restartCount > 5) | 
        "\(.metadata.name) - Restarts: \(.status.containerStatuses[0].restartCount) - Age: \(.metadata.creationTimestamp)"' \
        | tee "$DIAGNOSTICS_DIR/high-restart-pods.txt"
    
    # 3. CrashLoopBackOff Pods
    log_section "3. CrashLoopBackOff Detection"
    kubectl get pods -n "$NAMESPACE" -o json | \
        jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting?.reason == "CrashLoopBackOff") | 
        .metadata.name' | tee "$DIAGNOSTICS_DIR/crashloop-pods.txt"
    
    CRASHLOOP_PODS=$(cat "$DIAGNOSTICS_DIR/crashloop-pods.txt")
    
    if [ -n "$CRASHLOOP_PODS" ]; then
        log_warn "Found CrashLoopBackOff pods:"
        echo "$CRASHLOOP_PODS"
        
        # Collect logs and describe for each crashloop pod
        while IFS= read -r pod; do
            if [ -n "$pod" ]; then
                log_info "Collecting diagnostics for: $pod"
                
                # Pod describe
                kubectl describe pod -n "$NAMESPACE" "$pod" \
                    > "$DIAGNOSTICS_DIR/describe-$pod.txt" 2>&1
                
                # Pod logs (all containers)
                kubectl logs -n "$NAMESPACE" "$pod" --all-containers=true --tail=200 \
                    > "$DIAGNOSTICS_DIR/logs-$pod.txt" 2>&1 || true
                
                # Previous logs if restarted
                kubectl logs -n "$NAMESPACE" "$pod" --previous --all-containers=true --tail=200 \
                    > "$DIAGNOSTICS_DIR/logs-previous-$pod.txt" 2>&1 || true
            fi
        done <<< "$CRASHLOOP_PODS"
    else
        log_info "No CrashLoopBackOff pods found"
    fi
    
    # 4. ConfigMaps Analysis (Grafana Datasources)
    log_section "4. Analyzing Grafana Datasources"
    kubectl get cm -n "$NAMESPACE" -l grafana_datasource=1 \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
        | tee "$DIAGNOSTICS_DIR/datasource-configmaps.txt"
    
    # Check for isDefault conflicts
    log_info "Checking isDefault conflicts..."
    {
        echo "=== Loki Datasource ==="
        kubectl get cm -n "$NAMESPACE" loki-loki-stack -o yaml 2>/dev/null | grep -A5 "isDefault" || echo "Not found"
        echo ""
        echo "=== Prometheus Datasource ==="
        kubectl get cm -n "$NAMESPACE" monitorgrafana-kube-promet-grafana-datasource -o yaml 2>/dev/null | grep -A5 "isDefault" || echo "Not found"
    } | tee "$DIAGNOSTICS_DIR/datasource-isdefault-check.txt"
    
    # 5. Events Analysis
    log_section "5. Recent Events in Monitoring Namespace"
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -50 \
        | tee "$DIAGNOSTICS_DIR/recent-events.txt"
    
    # 6. Service Status
    log_section "6. Service Endpoints"
    kubectl get svc -n "$NAMESPACE" -o wide | tee "$DIAGNOSTICS_DIR/services.txt"
    
    # 7. Storage Analysis
    log_section "7. PVC Status"
    kubectl get pvc -n "$NAMESPACE" -o wide | tee "$DIAGNOSTICS_DIR/pvc-status.txt"
    
    # 8. Resource Usage
    log_section "8. Resource Usage"
    kubectl top pods -n "$NAMESPACE" 2>/dev/null | tee "$DIAGNOSTICS_DIR/resource-usage.txt" || \
        log_warn "Metrics server not available"
    
    # 9. Generate Summary
    log_section "9. Generating Summary Report"
    {
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║        OBSERVABILITY STACK DIAGNOSTICS SUMMARY        ║"
        echo "╚════════════════════════════════════════════════════════╝"
        echo ""
        echo "Timestamp: $(date)"
        echo "Namespace: $NAMESPACE"
        echo ""
        echo "════════════════════════════════════════════════════════"
        echo "POD STATUS SUMMARY"
        echo "════════════════════════════════════════════════════════"
        kubectl get pods -n "$NAMESPACE" --no-headers | awk '
        BEGIN {running=0; pending=0; failed=0; crashloop=0; other=0}
        {
            if ($3 == "Running") running++
            else if ($3 == "Pending") pending++
            else if ($3 == "Failed") failed++
            else if ($3 ~ /CrashLoop/) crashloop++
            else other++
        }
        END {
            print "Running:          " running
            print "Pending:          " pending
            print "Failed:           " failed
            print "CrashLoopBackOff: " crashloop
            print "Other:            " other
            print "TOTAL:            " running+pending+failed+crashloop+other
        }'
        echo ""
        echo "════════════════════════════════════════════════════════"
        echo "HIGH RESTART COUNT PODS"
        echo "════════════════════════════════════════════════════════"
        if [ -s "$DIAGNOSTICS_DIR/high-restart-pods.txt" ]; then
            cat "$DIAGNOSTICS_DIR/high-restart-pods.txt"
        else
            echo "No pods with high restart count (>5)"
        fi
        echo ""
        echo "════════════════════════════════════════════════════════"
        echo "CRASHLOOP PODS DETECTED"
        echo "════════════════════════════════════════════════════════"
        if [ -s "$DIAGNOSTICS_DIR/crashloop-pods.txt" ]; then
            cat "$DIAGNOSTICS_DIR/crashloop-pods.txt"
        else
            echo "No CrashLoopBackOff pods detected"
        fi
        echo ""
        echo "════════════════════════════════════════════════════════"
        echo "NEXT STEPS"
        echo "════════════════════════════════════════════════════════"
        echo "1. Review DIAGNOSTICS-SUMMARY.txt (this file)"
        echo "2. Check describe-*.txt files for pod details"
        echo "3. Review logs-*.txt files for error patterns"
        echo "4. Check datasource-isdefault-check.txt for conflicts"
        echo ""
        echo "Output Directory: $DIAGNOSTICS_DIR"
    } | tee "$DIAGNOSTICS_DIR/DIAGNOSTICS-SUMMARY.txt"
    
    # Final output
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║             DIAGNOSTICS COLLECTION COMPLETE            ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    echo "📁 Output Location:"
    echo "   $DIAGNOSTICS_DIR"
    echo ""
    echo "📋 Key Files:"
    echo "   - DIAGNOSTICS-SUMMARY.txt (start here)"
    echo "   - crashloop-pods.txt (problematic pods)"
    echo "   - logs-*.txt (pod logs)"
    echo "   - describe-*.txt (pod details)"
    echo ""
}

main "$@"
