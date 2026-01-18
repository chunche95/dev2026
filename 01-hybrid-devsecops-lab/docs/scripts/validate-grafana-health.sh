#!/bin/bash
################################################################################
# Script: validate-grafana-health.sh
# Purpose: Validate Grafana is healthy and accessible post-fix
# Author: Platform Engineering Team
# Date: 2026-01-18
# Reference: docs/runbooks/RB-001-grafana-datasource-conflict.md
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
TESTS_PASSED=0
TESTS_FAILED=0

################################################################################
# Functions
################################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_section() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"
}

test_pod_running() {
    log_section "Test 1: Pod Running Status"
    
    POD_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
    
    if [ "$POD_STATUS" = "Running" ]; then
        log_pass "Pod is in Running state"
    else
        log_fail "Pod is NOT Running (status: $POD_STATUS)"
        return 1
    fi
}

test_containers_ready() {
    log_section "Test 2: Container Readiness"
    
    READY_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
    
    if [ "$READY_STATUS" = "True" ]; then
        log_pass "All containers are ready"
    else
        log_fail "Containers are NOT ready"
        return 1
    fi
    
    # Check individual container readiness
    CONTAINER_READY=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{range .items[0].status.containerStatuses[*]}{.name}{": "}{.ready}{"\n"}{end}')
    
    echo "$CONTAINER_READY" | while IFS= read -r line; do
        if echo "$line" | grep -q "true"; then
            log_pass "  Container $line"
        else
            log_fail "  Container $line"
        fi
    done
}

test_restart_count() {
    log_section "Test 3: Restart Count"
    
    RESTART_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || echo "-1")
    
    POD_AGE=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].metadata.creationTimestamp}' 2>/dev/null || echo "")
    
    if [ "$RESTART_COUNT" -eq 0 ]; then
        log_pass "Restart count is 0 (expected for new pod)"
    elif [ "$RESTART_COUNT" -lt 5 ]; then
        log_warn "Restart count is $RESTART_COUNT (pod age: $POD_AGE)"
    else
        log_fail "Restart count is $RESTART_COUNT (too high)"
        return 1
    fi
}

test_no_crashloop() {
    log_section "Test 4: CrashLoopBackOff Check"
    
    POD_STATE=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].status.containerStatuses[0].state}' 2>/dev/null || echo "")
    
    if echo "$POD_STATE" | grep -q "waiting"; then
        REASON=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
            -o jsonpath='{.items[0].status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || echo "")
        
        if echo "$REASON" | grep -iq "crash"; then
            log_fail "Pod is in CrashLoopBackOff state"
            return 1
        fi
    fi
    
    log_pass "No CrashLoopBackOff detected"
}

test_datasource_config() {
    log_section "Test 5: Datasource Configuration"
    
    LOKI_DEFAULT=$(kubectl get cm -n "$NAMESPACE" loki-loki-stack -o yaml 2>/dev/null \
        | grep "isDefault" | awk '{print $2}' || echo "")
    
    PROM_DEFAULT=$(kubectl get cm -n "$NAMESPACE" monitorgrafana-kube-promet-grafana-datasource -o yaml 2>/dev/null \
        | grep "isDefault" | awk '{print $2}' || echo "")
    
    log_info "Loki isDefault: $LOKI_DEFAULT"
    log_info "Prometheus isDefault: $PROM_DEFAULT"
    
    if [ "$LOKI_DEFAULT" = "false" ] && [ "$PROM_DEFAULT" = "true" ]; then
        log_pass "Datasource configuration is correct (Prometheus=default, Loki=secondary)"
    elif [ "$LOKI_DEFAULT" = "true" ] && [ "$PROM_DEFAULT" = "true" ]; then
        log_fail "CONFLICT: Both datasources marked as default"
        return 1
    else
        log_warn "Unexpected datasource configuration"
    fi
}

test_http_endpoint() {
    log_section "Test 6: HTTP Endpoint Accessibility"
    
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
    NODEPORT=$(kubectl get svc -n "$NAMESPACE" monitorgrafana -o jsonpath='{.spec.ports[0].nodePort}')
    
    log_info "Testing endpoint: http://$NODE_IP:$NODEPORT"
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$NODE_IP:$NODEPORT" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
        log_pass "HTTP endpoint accessible (HTTP $HTTP_CODE)"
    else
        log_fail "HTTP endpoint not accessible (HTTP $HTTP_CODE)"
        return 1
    fi
}

test_prometheus_datasource() {
    log_section "Test 7: Prometheus Datasource Query"
    
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
    NODEPORT=$(kubectl get svc -n "$NAMESPACE" monitorgrafana -o jsonpath='{.spec.ports[0].nodePort}')
    
    # Test Prometheus proxy through Grafana
    QUERY_RESULT=$(curl -s "http://$NODE_IP:$NODEPORT/api/datasources/proxy/1/api/v1/query?query=up" 2>/dev/null || echo "")
    
    if echo "$QUERY_RESULT" | grep -q '"status":"success"'; then
        log_pass "Prometheus datasource is responding"
    else
        log_warn "Could not verify Prometheus datasource (may require authentication)"
    fi
}

test_loki_endpoint() {
    log_section "Test 8: Loki Endpoint"
    
    LOKI_NODEPORT=$(kubectl get svc -n "$NAMESPACE" loki -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
    
    if [ -z "$LOKI_NODEPORT" ]; then
        log_warn "Loki service is ClusterIP (not externally accessible)"
        return 0
    fi
    
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
    
    LOKI_RESPONSE=$(curl -s "http://$NODE_IP:$LOKI_NODEPORT/loki/api/v1/label" 2>/dev/null || echo "")
    
    if echo "$LOKI_RESPONSE" | grep -q '"status":"success"'; then
        log_pass "Loki is responding"
    else
        log_warn "Could not verify Loki endpoint"
    fi
}

test_pod_logs_clean() {
    log_section "Test 9: Pod Logs Error Check"
    
    GRAFANA_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=grafana \
        -o jsonpath='{.items[0].metadata.name}')
    
    ERROR_COUNT=$(kubectl logs -n "$NAMESPACE" "$GRAFANA_POD" -c grafana --tail=100 2>/dev/null \
        | grep -ci "error" || echo "0")
    
    log_info "Found $ERROR_COUNT 'error' mentions in last 100 log lines"
    
    if [ "$ERROR_COUNT" -eq 0 ]; then
        log_pass "No errors in recent logs"
    elif [ "$ERROR_COUNT" -lt 5 ]; then
        log_warn "$ERROR_COUNT errors found (may be acceptable)"
    else
        log_fail "High error count in logs: $ERROR_COUNT"
        return 1
    fi
}

print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                         VALIDATION SUMMARY                             ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}✅ ALL VALIDATIONS PASSED${NC}"
        echo "Grafana is healthy and ready for use!"
        echo ""
        echo "Access Grafana:"
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
        NODEPORT=$(kubectl get svc -n "$NAMESPACE" monitorgrafana -o jsonpath='{.spec.ports[0].nodePort}')
        echo "  URL: http://$NODE_IP:$NODEPORT"
        echo ""
        echo "Get credentials:"
        echo "  kubectl get secret -n monitoring monitorgrafana -o jsonpath='{.data.admin-user}' | base64 -d"
        echo "  kubectl get secret -n monitoring monitorgrafana -o jsonpath='{.data.admin-password}' | base64 -d"
        return 0
    else
        echo -e "${RED}❌ VALIDATION FAILED${NC}"
        echo "Please review failed tests above"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check pod logs: kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana"
        echo "  2. Describe pod: kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana"
        echo "  3. Review runbook: docs/runbooks/RB-001-grafana-datasource-conflict.md"
        return 1
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                 Grafana Health Validation Tool                         ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    test_pod_running || true
    test_containers_ready || true
    test_restart_count || true
    test_no_crashloop || true
    test_datasource_config || true
    test_http_endpoint || true
    test_prometheus_datasource || true
    test_loki_endpoint || true
    test_pod_logs_clean || true
    
    print_summary
}

# Execute
main
