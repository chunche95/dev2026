# Incident Report: Grafana CrashLoopBackOff

**Incident ID**: `GRAFANA-CRASHLOOP-2026-01-18`  
**Severity**: P1 (Critical)  
**Status**: ✅ RESOLVED  
**Date Opened**: 2026-01-18 21:00 UTC  
**Date Resolved**: 2026-01-18 21:22 UTC  
**Time to Resolution**: 22 minutes  
**Assignee**: Paulino (IST → ISA candidate)  

---

## Executive Summary

Grafana pod in the monitoring namespace was in **CrashLoopBackOff** state for **135 days** (226 restarts) due to a datasource provisioning conflict. Two Helm charts (`kube-prometheus-stack` and `loki-stack`) both configured their datasources as `isDefault: true`, violating Grafana v12.1.0's single-default-datasource requirement.

**Impact**: Complete loss of Grafana dashboard access for 135 days. Prometheus and Loki continued collecting data, but visualization was unavailable.

**Resolution**: Patched Loki datasource ConfigMap to `isDefault: false`, keeping Prometheus as default. Pod recovered in <5 minutes.

---

## Impact Assessment

| Metric | Value |
|--------|-------|
| **Affected Service** | Grafana Dashboard (Observability Stack) |
| **Users Impacted** | All engineers requiring cluster observability |
| **Service Availability** | 0% (CrashLoopBackOff) |
| **Data Loss** | None (metrics/logs continued collection) |
| **Business Impact** | High - No visibility into cluster health |
| **Downtime Duration** | 135 days (undetected) |

---

## Timeline

```
2025-09-05 15:38 UTC  | Grafana pod deployed, entered CrashLoopBackOff
                      | Root cause: Datasource conflict introduced
                      |
         ↓            |
    135 DAYS          | Pod continuously crashing (226 restarts)
         ↓            | Issue undetected - no monitoring on monitoring stack
                      |
2026-01-18 21:00 UTC  | Issue discovered during cluster audit
2026-01-18 21:05 UTC  | Root cause identified via pod logs
2026-01-18 21:10 UTC  | ConfigMap patched (Loki datasource)
2026-01-18 21:15 UTC  | Pod deleted, new pod created
2026-01-18 21:17 UTC  | New pod reached Running state (3/3 containers)
2026-01-18 21:22 UTC  | HTTP endpoint validated, incident RESOLVED
```

---

## Next Steps

1. ✅ Create detailed Root Cause Analysis (see `ROOT_CAUSE_ANALYSIS.md`)
2. ✅ Document solution implementation (see `SOLUTION.md`)
3. ⏳ Create ADR for datasource default decision
4. ⏳ Implement alerting on Grafana pod health
5. ⏳ Review other multi-chart Helm deployments for similar conflicts

---

## Related Documents

- **Root Cause Analysis**: `ROOT_CAUSE_ANALYSIS.md`
- **Solution Documentation**: `SOLUTION.md`
- **Architecture Decision**: `../../architecture/decisions/ADR-003-grafana-datasource-conflict.md`
- **Evidence**: `./evidence/`
- **Scripts**: `./scripts/`
