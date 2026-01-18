# Incident Report: INC-2026-01-18-GRAFANA-CRASHLOOP

## Incident Summary

| Field | Value |
|-------|-------|
| **Incident ID** | INC-2026-01-18-GRAFANA-CRASHLOOP |
| **Date Detected** | 2026-01-18 21:00 UTC |
| **Date Resolved** | 2026-01-18 21:22 UTC |
| **Severity** | P1 - Critical |
| **Status** | ✅ Resolved |
| **Time to Resolution** | 22 minutes |
| **Affected Service** | Grafana Dashboard (Observability Stack) |
| **Impact Duration** | 135 days (undetected until investigation) |

---

## Impact Assessment

### Business Impact
- **Severity**: Critical
- **Affected Users**: All engineers requiring cluster observability
- **Service Degradation**: 100% unavailable (CrashLoopBackOff)
- **Data Loss**: None (Prometheus/Loki continued collecting data)

### Technical Impact
```
Component: Grafana v12.1.0
Status: CrashLoopBackOff (226 restarts over 135 days)
Pod: monitorgrafana-677d8d6465-tktwr
Namespace: monitoring
Error: "Datasource provisioning error: Only one datasource per organization can be marked as default"
```

---

## Timeline

| Time (UTC) | Event |
|------------|-------|
| 2025-09-05 15:38 | Grafana pod deployed, entered CrashLoopBackOff |
| 2025-09-05 → 2026-01-18 | **135 days** of continuous crashes (226 restarts) |
| 2026-01-18 21:00 | Issue detected during cluster audit |
| 2026-01-18 21:05 | Root cause analysis completed |
| 2026-01-18 21:10 | ConfigMap patched (Loki datasource) |
| 2026-01-18 21:15 | Pod deleted, new pod created |
| 2026-01-18 21:17 | New pod reached Running state (3/3) |
| 2026-01-18 21:22 | HTTP endpoint validated, incident resolved |

---

## Root Cause Analysis

### Problem Statement
Grafana pod failed to start due to conflicting datasource configurations. Two datasources were marked as `isDefault: true`, violating Grafana's single-default-datasource requirement.

### Contributing Factors
1. **Multiple Helm Charts**: Separate deployments of `kube-prometheus-stack` and `loki-stack`
2. **Default Configuration**: Both charts default their datasources to `isDefault: true`
3. **Grafana Version**: v12.1.0 enforces strict validation (earlier versions may have been permissive)
4. **Lack of Monitoring**: No alerting on Grafana pod health

### Technical Root Cause

#### ConfigMap Analysis
**Loki Datasource** (`loki-loki-stack`):
```yaml
datasources:
- name: Loki
  type: loki
  url: "http://loki:3100"
  isDefault: true  # ❌ CONFLICT
```

**Prometheus Datasource** (`monitorgrafana-kube-promet-grafana-datasource`):
```yaml
datasources:
- name: "Prometheus"
  type: prometheus
  url: http://monitorgrafana-kube-promet-prometheus.monitoring:9090/
  isDefault: true  # ❌ CONFLICT
```

#### Error Message
```
logger=provisioning t=2026-01-18T20:54:26Z level=error 
msg="Failed to provision data sources" 
error="Datasource provisioning error: datasource.yaml config is invalid. 
Only one datasource per organization can be marked as default"
```

---

## Resolution

### Solution Applied
Changed Loki datasource from `isDefault: true` to `isDefault: false`, keeping Prometheus as the default datasource.

**Rationale**:
- Prometheus: Cluster-wide metrics, primary monitoring use case
- Loki: Log aggregation, secondary/specialized use case
- Users can manually select Loki datasource when needed

### Commands Executed

#### 1. Backup Original Configuration
```bash
kubectl get cm -n monitoring loki-loki-stack -o yaml \
  > ~/cluster-audit/observability/loki-datasource-BACKUP.yaml
```

#### 2. Patch ConfigMap
```bash
kubectl patch cm -n monitoring loki-loki-stack --type='json' \
  -p='[{"op": "replace", "path": "/data/loki-stack-datasource.yaml", 
  "value": "apiVersion: 1\ndatasources:\n- name: Loki\n  type: loki\n  
  access: proxy\n  url: \"http://loki:3100\"\n  version: 1\n  
  isDefault: false\n  jsonData:\n    {}\n"}]'
```

#### 3. Trigger Pod Restart
```bash
kubectl delete pod -n monitoring monitorgrafana-677d8d6465-tktwr
```

#### 4. Validation
```bash
# Verify pod is running
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Verify HTTP endpoint
curl -I http://192.168.0.18:31968
```

### Results
```
BEFORE:
  Pod: monitorgrafana-677d8d6465-tktwr
  Status: CrashLoopBackOff
  Restarts: 226
  Age: 135 days
  HTTP Response: Connection refused

AFTER:
  Pod: monitorgrafana-677d8d6465-sfz69
  Status: Running (3/3)
  Restarts: 0
  Age: 96 seconds
  HTTP Response: 302 /login (SUCCESS)
```

---

## Lessons Learned

### What Went Well
- ✅ Root cause identified quickly (5 minutes)
- ✅ Fix applied without service disruption
- ✅ No data loss (Prometheus/Loki continued operating)
- ✅ Surgical fix (patch ConfigMap, no helm redeploy needed)

### What Went Wrong
- ❌ Issue undetected for 135 days (lack of pod health monitoring)
- ❌ No alerting on CrashLoopBackOff pods
- ❌ Grafana dashboard unavailable for 4+ months

### Action Items

| Priority | Action | Owner | Due Date | Status |
|----------|--------|-------|----------|--------|
| P0 | Create alert for CrashLoopBackOff pods | SRE Team | 2026-01-20 | ⏳ Pending |
| P1 | Document multi-datasource provisioning | Platform Eng | 2026-01-22 | ⏳ Pending |
| P2 | Create runbook RB-001 | Platform Eng | 2026-01-22 | ✅ Done |
| P2 | Create ADR-003 | Platform Eng | 2026-01-22 | ✅ Done |
| P3 | Review Helm chart defaults | Platform Eng | 2026-01-25 | ⏳ Pending |

---

## References
- **Runbook**: [RB-001: Grafana Datasource Conflict](../runbooks/RB-001-grafana-datasource-conflict.md)
- **ADR**: [ADR-003: Grafana Datasource Default Strategy](../adr/ADR-003-grafana-datasource-default.md)
- **Backup**: `~/cluster-audit/observability/loki-datasource-BACKUP.yaml`
- **Grafana Logs**: `docs/info/logs-monitorgrafana-677d8d6465-tktwr.txt`

---

## Metadata
- **Report Author**: Platform Engineering Team
- **Reviewers**: SRE Team, DevOps Lead
- **Created**: 2026-01-18
- **Last Updated**: 2026-01-18
- **Incident Category**: Observability, Configuration
