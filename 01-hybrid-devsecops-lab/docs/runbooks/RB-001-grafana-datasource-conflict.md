# Runbook: RB-001 - Grafana Datasource Conflict Resolution

## Overview
**Runbook ID**: RB-001  
**Service**: Grafana (Observability Stack)  
**Category**: Configuration, Troubleshooting  
**Severity**: P1 - Critical  
**Last Updated**: 2026-01-18  

---

## Purpose
This runbook provides step-by-step instructions to diagnose and resolve Grafana CrashLoopBackOff caused by multiple datasources marked as `isDefault: true`.

---

## Symptoms
- ✅ Grafana pod in CrashLoopBackOff state
- ✅ High restart count (100+ restarts)
- ✅ Dashboard HTTP endpoint unreachable
- ✅ Error in logs: `"Only one datasource per organization can be marked as default"`

---

## Prerequisites
- kubectl access to monitoring namespace
- Backup directory: `~/cluster-audit/observability/`

---

## Diagnosis Steps

### 1. Verify Pod Status
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
```

**Expected Output** (if issue exists):
```
NAME                              READY   STATUS             RESTARTS   AGE
monitorgrafana-xxx                2/3     CrashLoopBackOff   100+       XXd
```

### 2. Check Pod Logs
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana \
  -c grafana --tail=50 | grep -i "error\|failed"
```

**Look for**:
```
error="Datasource provisioning error: datasource.yaml config is invalid. 
Only one datasource per organization can be marked as default"
```

### 3. List All Datasource ConfigMaps
```bash
kubectl get cm -n monitoring -l grafana_datasource=1 -o name
```

### 4. Check Each ConfigMap for isDefault
```bash
kubectl get cm -n monitoring loki-loki-stack -o yaml | grep -A 5 "isDefault"
kubectl get cm -n monitoring monitorgrafana-kube-promet-grafana-datasource -o yaml | grep -A 5 "isDefault"
```

**Problem Confirmed If**: Multiple ConfigMaps have `isDefault: true`

---

## Resolution Procedure

### Phase 1: Backup Current Configuration

```bash
# Create backup directory
mkdir -p ~/cluster-audit/observability/backups

# Backup Loki datasource
kubectl get cm -n monitoring loki-loki-stack -o yaml \
  > ~/cluster-audit/observability/backups/loki-datasource-$(date +%Y%m%d-%H%M%S).yaml

# Backup Prometheus datasource
kubectl get cm -n monitoring monitorgrafana-kube-promet-grafana-datasource -o yaml \
  > ~/cluster-audit/observability/backups/prometheus-datasource-$(date +%Y%m%d-%H%M%S).yaml
```

**Verification**:
```bash
ls -lh ~/cluster-audit/observability/backups/
```

---

### Phase 2: Decide Which Datasource Should Be Default

**Decision Matrix**:

| Datasource | Use Case | Recommendation |
|------------|----------|----------------|
| Prometheus | Cluster metrics, resource monitoring | ✅ **isDefault: true** |
| Loki | Log aggregation | ⚠️ **isDefault: false** |

**Rationale**: Prometheus serves cluster-wide dashboards (CPU, memory, pods). Loki is for specialized log analysis.

---

### Phase 3: Apply Fix

#### Option A: Patch ConfigMap (Recommended)
```bash
# Patch Loki datasource to isDefault: false
kubectl patch cm -n monitoring loki-loki-stack --type='json' \
  -p='[{"op": "replace", "path": "/data/loki-stack-datasource.yaml", 
  "value": "apiVersion: 1\ndatasources:\n- name: Loki\n  type: loki\n  access: proxy\n  url: \"http://loki:3100\"\n  version: 1\n  isDefault: false\n  jsonData:\n    {}\n"}]'
```

#### Option B: Edit ConfigMap Manually
```bash
kubectl edit cm -n monitoring loki-loki-stack

# Change:
#   isDefault: true
# To:
#   isDefault: false
```

---

### Phase 4: Trigger Pod Restart

```bash
# Get current Grafana pod name
GRAFANA_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')

# Delete pod (will be recreated by ReplicaSet)
kubectl delete pod -n monitoring $GRAFANA_POD

# Wait for new pod
kubectl wait --for=condition=ready pod -n monitoring \
  -l app.kubernetes.io/name=grafana --timeout=120s
```

---

### Phase 5: Validation

#### 1. Verify Pod Status
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
```

**Expected Output**:
```
NAME                              READY   STATUS    RESTARTS   AGE
monitorgrafana-xxx                3/3     Running   0          XXs
```

#### 2. Check Restart Count
```bash
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana | grep "Restart Count"
```

**Expected**: All restart counts = 0

#### 3. Verify HTTP Endpoint
```bash
curl -I http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):31968
```

**Expected Output**:
```
HTTP/1.1 302 Found
Location: /login
```

#### 4. Verify Datasources in Grafana UI
```bash
# Get Grafana credentials
echo "Username: $(kubectl get secret -n monitoring monitorgrafana -o jsonpath='{.data.admin-user}' | base64 -d)"
echo "Password: $(kubectl get secret -n monitoring monitorgrafana -o jsonpath='{.data.admin-password}' | base64 -d)"
```

**Manual Steps**:
1. Access Grafana: `http://<NODE_IP>:31968`
2. Login with credentials
3. Navigate to: Configuration → Data Sources
4. Verify:
   - ✅ Prometheus: **Default badge visible**
   - ✅ Loki: **No default badge**

#### 5. Test Prometheus Queries
```bash
curl -s "http://<NODE_IP>:31968/api/datasources/proxy/1/api/v1/query?query=up" | jq -r '.status'
```

**Expected**: `"success"`

#### 6. Test Loki Queries
```bash
curl -s "http://<NODE_IP>:30995/loki/api/v1/label" | jq -r '.status'
```

**Expected**: `"success"`

---

## Rollback Procedure

If fix causes issues, restore from backup:

```bash
# Restore original Loki ConfigMap
kubectl apply -f ~/cluster-audit/observability/backups/loki-datasource-<TIMESTAMP>.yaml

# Restart Grafana pod
kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana

# Verify restoration
kubectl get cm -n monitoring loki-loki-stack -o yaml | grep isDefault
```

---

## Prevention & Monitoring

### Recommended Alerts

**PrometheusRule**:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: grafana-health
  namespace: monitoring
spec:
  groups:
  - name: grafana
    interval: 30s
    rules:
    - alert: GrafanaPodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total{namespace="monitoring",pod=~".*grafana.*"}[15m]) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Grafana pod is crash looping"
        description: "Pod {{ $labels.pod }} has restarted {{ $value }} times in the last 15 minutes"
```

### Best Practices
1. ✅ Always backup ConfigMaps before modification
2. ✅ Use Helm values to configure datasource defaults
3. ✅ Document which datasource should be default in ADR
4. ✅ Monitor pod restart counts
5. ✅ Test changes in staging before production

---

## Related Documents
- **Incident Report**: [INC-2026-01-18-GRAFANA-CRASHLOOP](../incidents/INC-2026-01-18-grafana-crashloop.md)
- **ADR**: [ADR-003: Grafana Datasource Default Strategy](../adr/ADR-003-grafana-datasource-default.md)
- **Grafana Docs**: https://grafana.com/docs/grafana/latest/datasources/

---

## Metadata
- **Author**: Platform Engineering Team
- **Reviewers**: SRE Team
- **Created**: 2026-01-18
- **Tested**: ✅ 2026-01-18 (Production)
- **Next Review**: 2026-04-18
