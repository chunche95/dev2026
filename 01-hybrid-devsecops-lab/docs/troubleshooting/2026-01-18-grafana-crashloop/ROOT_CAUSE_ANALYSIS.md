# Root Cause Analysis: Grafana CrashLoopBackOff

**Incident ID**: `GRAFANA-CRASHLOOP-2026-01-18`  
**Analyzed By**: Paulino  
**Date**: 2026-01-18  

---

## Problem Statement

Grafana pod failed to start with error:
```
Datasource provisioning error: datasource.yaml config is invalid. 
Only one datasource per organization can be marked as default
```

Pod remained in **CrashLoopBackOff** for **135 days** with **226 restarts**.

---

## Investigation Process

### 1. Initial Discovery

**Command**:
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
```

**Output**:
```
NAME                              READY   STATUS             RESTARTS      AGE
monitorgrafana-677d8d6465-tktwr   2/3     CrashLoopBackOff   226 (3m ago)  135d
```

**Observation**: Pod in crash state for 135 days, never achieved Running status.

---

### 2. Log Analysis

**Command**:
```bash
kubectl logs -n monitoring monitorgrafana-677d8d6465-tktwr -c grafana --tail=100
```

**Key Error**:
```
logger=provisioning.datasources t=2026-01-18T20:54:26.431274088Z 
level=error msg="Failed to provision data sources" 
error="Datasource provisioning error: datasource.yaml config is invalid. 
Only one datasource per organization can be marked as default"
```

**Analysis**: Grafana sidecar (`grafana-sc-datasources`) watches ConfigMaps with label `grafana_datasource: "1"` and provisions datasources. Multiple ConfigMaps marked datasources as `isDefault: true`.

---

### 3. ConfigMap Investigation

**Command**:
```bash
kubectl get cm -n monitoring -l grafana_datasource=1
```

**Output**:
```
NAME                                              DATA   AGE
loki-loki-stack                                   1      144d
monitorgrafana-kube-promet-grafana-datasource     1      144d
```

**Analysis**: Two ConfigMaps both provisioning datasources.

#### ConfigMap: `loki-loki-stack`

**Command**:
```bash
kubectl get cm -n monitoring loki-loki-stack -o yaml
```

**Datasource Configuration**:
```yaml
apiVersion: 1
datasources:
- name: Loki
  type: loki
  access: proxy
  url: "http://loki:3100"
  version: 1
  isDefault: true  # ❌ PROBLEM
  jsonData: {}
```

---

#### ConfigMap: `monitorgrafana-kube-promet-grafana-datasource`

**Command**:
```bash
kubectl get cm -n monitoring monitorgrafana-kube-promet-grafana-datasource -o yaml
```

**Datasource Configuration**:
```yaml
apiVersion: 1
datasources:
- name: "Prometheus"
  type: prometheus
  url: http://monitorgrafana-kube-promet-prometheus.monitoring:9090/
  access: proxy
  isDefault: true  # ❌ CONFLICT
  jsonData:
    timeInterval: "30s"
```

---

## Root Cause

### Primary Cause
**Two datasources marked as `isDefault: true`** in a single Grafana organization, violating Grafana's datasource provisioning rules.

### Contributing Factors

1. **Separate Helm Chart Deployments**
   - `kube-prometheus-stack` chart deploys Prometheus + Grafana
   - `loki-stack` chart deploys Loki + Promtail
   - Each chart independently configures its datasource as default

2. **Helm Chart Defaults**
   - Both charts use `isDefault: true` in their default values
   - No coordination between chart installations

3. **Grafana Version Strictness**
   - Grafana v12.1.0 enforces strict validation
   - Older versions may have been permissive or issued warnings

4. **Lack of Observability on Observability**
   - No alerting configured for Grafana pod health
   - CrashLoopBackOff went undetected for 135 days

---

## Why This Wasn't Detected Earlier

### Missing Monitoring
- ❌ No AlertManager rule for pod CrashLoopBackOff in monitoring namespace
- ❌ No health checks on Grafana HTTP endpoint
- ❌ No Slack/PagerDuty integration for critical alerts

### Symptom Masking
- ✅ Prometheus continued collecting metrics normally
- ✅ Loki continued collecting logs normally
- ❌ Grafana dashboard unavailable, but no alerts triggered

### Operational Gap
- Manual cluster audits not performed regularly
- Assumption that "all pods running" = "all services healthy"

---

## The "5 Whys" Analysis

**Why did Grafana crash?**  
→ Two datasources marked as `isDefault: true`

**Why were two datasources marked as default?**  
→ Two Helm charts independently configured their datasources

**Why didn't the Helm charts coordinate?**  
→ Charts installed separately without values override

**Why wasn't this detected during installation?**  
→ No post-deployment validation of Grafana accessibility

**Why did this persist for 135 days?**  
→ No monitoring/alerting on monitoring stack health

---

## Lessons Learned

### Technical
1. **Multi-chart deployments require coordination**
   - Override values files when combining charts
   - Validate datasource defaults before deployment

2. **Grafana sidecar pattern requires awareness**
   - Sidecar watches ConfigMaps with `grafana_datasource: "1"` label
   - All matching ConfigMaps are provisioned automatically

3. **Version-specific behavior**
   - Grafana v12.x enforces strict validation
   - Upgrades may expose previously-tolerated misconfigurations

### Operational
1. **Monitor the monitoring stack**
   - AlertManager rules for observability pods
   - Health checks on critical endpoints (Grafana, Prometheus)

2. **Post-deployment validation**
   - Verify all endpoints accessible after Helm install
   - Check pod logs for errors even if status = Running

3. **Regular cluster audits**
   - Scheduled reviews of pod health across all namespaces
   - Proactive troubleshooting vs reactive firefighting

---

## Recommendations

### Immediate (Completed ✅)
- ✅ Patch Loki datasource to `isDefault: false`
- ✅ Verify Grafana pod Running and HTTP accessible
- ✅ Document incident and root cause

### Short-term (Next Sprint)
- ⏳ Create AlertManager rule for monitoring namespace pod failures
- ⏳ Implement health check probe on Grafana endpoint
- ⏳ Add post-deployment validation to CI/CD pipeline

### Long-term (Backlog)
- ⏳ Consolidate monitoring stack into single Helm chart
- ⏳ Implement GitOps with ArgoCD for observability stack
- ⏳ Create runbook for monitoring stack recovery

---

## References

- **Incident Report**: `INCIDENT.md`
- **Solution Documentation**: `SOLUTION.md`
- **Grafana Provisioning Docs**: https://grafana.com/docs/grafana/latest/administration/provisioning/
- **Evidence Files**: `./evidence/grafana-crash-logs.txt`
