#!/bin/bash
################################################################################
# Script: validate-observability-stack.sh
# Purpose: Comprehensive validation of monitoring stack health
# Use Case: Run after fixing issues to confirm everything is operational
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

NAMESPACE="monitoring"
TESTS_PASSED=0
TESTS_FAILED=0

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((TESTS_FAILED++)); }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_section() { echo -e "\n${BLUE}==== $1 ====${NC}\n"; }

################################################################################
# Validation Tests
################################################################################

test_grafana_health() {
    log_section "1. Grafana Health Check"
    
    # Pod running
    if kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
        log_pass "Grafana pod is Running"
    else
        log_fail "Grafana pod is NOT Running"
        return 1
    fi
    
    # Containers ready
    READY=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [ "$READY" = "True" ]; then
        log_pass "Grafana containers are ready"
    else
        log_fail "Grafana containers NOT ready"
        return 1
    fi
    
    # HTTP endpoint
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
    GRAFANA_PORT=$(kubectl get svc -n "$NAMESPACE" monitorgrafana -o jsonpath='{.spec.ports[0].nodePort}')
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$NODE_IP:$GRAFANA_PORT" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
        log_pass "Grafana HTTP endpoint accessible (HTTP $HTTP_CODE)"
    else
        log_fail "Grafana HTTP endpoint NOT accessible (HTTP $HTTP_CODE)"
        return 1
    fi
}

test_prometheus_health() {
    log_section "2. Prometheus Health Check"
    
    # Pod running
    if kubectl get pods -n "$NAMESPACE" -l app=kube-prometheus-stack-prometheus \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
        log_pass "Prometheus pod is Running"
    else
        log_fail "Prometheus pod is NOT Running"
        return 1
    fi
    
    # HTTP endpoint
    PROM_PORT=$(kubectl get svc -n "$NAMESPACE" monitorgrafana-kube-promet-prometheus -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
    if [ -n "$PROM_PORT" ]; then
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$NODE_IP:$PROM_PORT/-/healthy" 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "200" ]; then
            log_pass "Prometheus HTTP endpoint healthy"
        else
            log_warn "Prometheus endpoint returned HTTP $HTTP_CODE"
        fi
    else
        log_warn "Prometheus service is ClusterIP (not exposed)"
    fi
}

test_loki_health() {
    log_section "3. Loki Health Check"
    
    # Pod running
    if kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=loki \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
        log_pass "Loki pod is Running"
    else
        log_fail "Loki pod is NOT Running"
        return 1
    fi
    
    # API endpoint
    LOKI_PORT=$(kubectl get svc -n "$NAMESPACE" loki -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
    if [ -n "$LOKI_PORT" ]; then
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
        LOKI_RESPONSE=$(curl -s "http://$NODE_IP:$LOKI_PORT/loki/api/v1/label" 2>/dev/null || echo "")
        if echo "$LOKI_RESPONSE" | grep -q '"status":"success"'; then
            log_pass "Loki API responding"
        else
            log_warn "Loki API not responding as expected"
        fi
    else
        log_warn "Loki service is ClusterIP (not exposed)"
    fi
}

test_alertmanager_health() {
    log_section "4. AlertManager Health Check"
    
    # Pod running
    if kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=alertmanager \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
        log_pass "AlertManager pod is Running"
    else
        log_fail "AlertManager pod is NOT Running"
        return 1
    fi
}

test_promtail_daemonset() {
    log_section "5. Promtail DaemonSet Check"
    
    DESIRED=$(kubectl get daemonset -n "$NAMESPACE" loki-promtail \
        -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
    READY=$(kubectl get daemonset -n "$NAMESPACE" loki-promtail \
        -o jsonpath='{.status.numberReady}' 2>/dev/null)
    
    if [ "$DESIRED" = "$READY" ]; then
        log_pass "Promtail DaemonSet ready ($READY/$DESIRED nodes)"
    else
        log_warn "Promtail DaemonSet partially ready ($READY/$DESIRED nodes)"
    fi
}

test_datasource_config() {
    log_section "6. Datasource Configuration Check"
    
    LOKI_DEFAULT=$(kubectl get cm -n "$NAMESPACE" loki-loki-stack -o yaml 2>/dev/null \
        | grep "isDefault" | awk '{print $2}' | head -1)
    PROM_DEFAULT=$(kubectl get cm -n "$NAMESPACE" monitorgrafana-kube-promet-grafana-datasource -o yaml 2>/dev/null \
        | grep "isDefault" | awk '{print $2}' | head -1)
    
    echo "  Loki isDefault: $LOKI_DEFAULT"
    echo "  Prometheus isDefault: $PROM_DEFAULT"
    
    if [ "$LOKI_DEFAULT" = "false" ] && [ "$PROM_DEFAULT" = "true" ]; then
        log_pass "Datasource configuration correct (Prometheus=default)"
    elif [ "$LOKI_DEFAULT" = "true" ] && [ "$PROM_DEFAULT" = "true" ]; then
        log_fail "CONFLICT: Both datasources marked as default"
        return 1
    else
        log_warn "Unexpected datasource configuration"
    fi
}

test_no_crashloops() {
    log_section "7. CrashLoopBackOff Detection"
    
    CRASHLOOP_COUNT=$(kubectl get pods -n "$NAMESPACE" -o json | \
        jq '[.items[] | select(.status.containerStatuses[]?.state.waiting?.reason == "CrashLoopBackOff")] | length')
    
    if [ "$CRASHLOOP_COUNT" -eq 0 ]; then
        log_pass "No pods in CrashLoopBackOff state"
    else
        log_fail "Found $CRASHLOOP_COUNT pod(s) in CrashLoopBackOff"
        kubectl get pods -n "$NAMESPACE" -o json | \
            jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting?.reason == "CrashLoopBackOff") | 
            "  - \(.metadata.name)"'
        return 1
    fi
}

test_persistent_storage() {
    log_section "8. Persistent Storage Check"
    
    PVC_COUNT=$(kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    BOUND_COUNT=$(kubectl get pvc -n "$NAMESPACE" -o json 2>/dev/null | \
        jq '[.items[] | select(.status.phase == "Bound")] | length')
    
    if [ "$PVC_COUNT" -eq "$BOUND_COUNT" ]; then
        log_pass "All PVCs are Bound ($BOUND_COUNT/$PVC_COUNT)"
    else
        log_warn "Some PVCs not Bound ($BOUND_COUNT/$PVC_COUNT)"
        kubectl get pvc -n "$NAMESPACE" --no-headers | grep -v "Bound" || true
    fi
}

test_service_discovery() {
    log_section "9. Service Discovery Check"
    
    # Check Prometheus targets
    PROM_PORT=$(kubectl get svc -n "$NAMESPACE" monitorgrafana-kube-promet-prometheus \
        -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
    
    if [ -n "$PROM_PORT" ]; then
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
        TARGETS=$(curl -s "http://$NODE_IP:$PROM_PORT/api/v1/targets" 2>/dev/null | \
            jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")
        
        if [ "$TARGETS" -gt 0 ]; then
            log_pass "Prometheus has $TARGETS active targets"
        else
            log_warn "Prometheus has no active targets"
        fi
    else
        log_warn "Cannot test Prometheus targets (service not exposed)"
    fi
}

test_pod_restarts() {
    log_section "10. High Restart Count Detection"
    
    HIGH_RESTART_PODS=$(kubectl get pods -n "$NAMESPACE" -o json | \
        jq -r '.items[] | select(.status.containerStatuses[]?.restartCount > 10) | 
        "\(.metadata.name): \(.status.containerStatuses[0].restartCount) restarts"')
    
    if [ -z "$HIGH_RESTART_PODS" ]; then
        log_pass "No pods with excessive restarts (>10)"
    else
        log_warn "Found pods with high restart count:"
        echo "$HIGH_RESTART_PODS" | while IFS= read -r line; do
            echo "  $line"
        done
    fi
}

print_summary() {
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║           VALIDATION SUMMARY                         ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    printf "Tests Passed: ${GREEN}%d${NC}\n" "$TESTS_PASSED"
    printf "Tests Failed: ${RED}%d${NC}\n" "$TESTS_FAILED"
    echo ""
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}✅ ALL VALIDATIONS PASSED${NC}"
        echo ""
        echo "Observability stack is fully operational!"
        echo ""
        echo "Access URLs:"
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
        GRAFANA_PORT=$(kubectl get svc -n "$NAMESPACE" monitorgrafana -o jsonpath='{.spec.ports[0].nodePort}')
        PROM_PORT=$(kubectl get svc -n "$NAMESPACE" monitorgrafana-kube-promet-prometheus -o jsonpath='{.spec.ports[0].nodePort}' || echo "N/A")
        
        echo "  Grafana:    http://$NODE_IP:$GRAFANA_PORT"
        [ "$PROM_PORT" != "N/A" ] && echo "  Prometheus: http://$NODE_IP:$PROM_PORT"
        echo ""
        echo "Next steps:"
        echo "  1. Access Grafana UI and verify dashboards"
        echo "  2. Check Prometheus targets: http://$NODE_IP:$PROM_PORT/targets"
        echo "  3. Test alert rules in AlertManager"
        return 0
    else
        echo -e "${RED}❌ VALIDATION FAILED${NC}"
        echo ""
        echo "Troubleshooting steps:"
        echo "  1. Review failed tests above"
        echo "  2. Run diagnostics: ./diagnose-observability-stack.sh"
        echo "  3. Check pod logs: kubectl logs -n monitoring <pod-name>"
        echo "  4. Consult runbooks in docs/runbooks/"
        return 1
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║     Observability Stack Validation Tool             ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    
    test_grafana_health || true
    test_prometheus_health || true
    test_loki_health || true
    test_alertmanager_health || true
    test_promtail_daemonset || true
    test_datasource_config || true
    test_no_crashloops || true
    test_persistent_storage || true
    test_service_discovery || true
    test_pod_restarts || true
    
    print_summary
}

main "$@"
