# ADR-003: Grafana Default Datasource Strategy

## Status
✅ **Accepted** (2026-01-18)

---

## Context

### Problem Statement
Grafana pod entered CrashLoopBackOff for 135 days due to multiple datasources configured as `isDefault: true`. This violates Grafana's constraint that only one datasource per organization can be marked as default.

### Background
The observability stack consists of:
- **kube-prometheus-stack** (Helm chart): Deploys Prometheus + Grafana
- **loki-stack** (Helm chart): Deploys Loki + Promtail

Both charts independently provision their respective datasources with `isDefault: true` in their default configurations, creating a conflict when deployed to the same Grafana instance.

### Technical Details
**Grafana Version**: 12.1.0  
**Error Message**:
```
Datasource provisioning error: datasource.yaml config is invalid. 
Only one datasource per organization can be marked as default
```

**Conflicting ConfigMaps**:
1. `loki-loki-stack`: Loki datasource (`isDefault: true`)
2. `monitorgrafana-kube-promet-grafana-datasource`: Prometheus (`isDefault: true`)

---

## Decision

**We will configure Prometheus as the default datasource and Loki as a secondary datasource.**

### Configuration
```yaml
# Prometheus (Default)
datasources:
- name: "Prometheus"
  type: prometheus
  url: http://monitorgrafana-kube-promet-prometheus.monitoring:9090/
  isDefault: true  ✅

# Loki (Secondary)
datasources:
- name: Loki
  type: loki
  url: "http://loki:3100"
  isDefault: false  ✅
```

---

## Rationale

### Why Prometheus as Default?

| Factor | Prometheus | Loki | Winner |
|--------|-----------|------|--------|
| **Primary Use Case** | Cluster-wide metrics | Application logs | Prometheus |
| **Dashboard Coverage** | 90% of default dashboards | 10% specialized | Prometheus |
| **User Frequency** | Daily (all engineers) | Ad-hoc (debugging) | Prometheus |
| **Data Volume** | Moderate | High (can be noisy) | Prometheus |
| **Query Latency** | Low (indexed metrics) | Higher (log search) | Prometheus |

### Prometheus Advantages
1. ✅ **Metrics-first approach**: Most Grafana dashboards query metrics (CPU, memory, network)
2. ✅ **Pre-built dashboards**: kube-prometheus-stack includes 20+ dashboards for Prometheus
3. ✅ **Common workflow**: Engineers check metrics first, then dig into logs if needed
4. ✅ **Performance**: Prometheus queries are faster for time-series data
5. ✅ **Alerting integration**: AlertManager rules are based on Prometheus metrics

### Loki as Secondary
1. ✅ **Specialized use case**: Log analysis is typically done when debugging specific issues
2. ✅ **Explicit selection**: Users can manually select Loki datasource when needed
3. ✅ **Reduces noise**: Default queries don't accidentally hit log storage
4. ✅ **Easy access**: Still accessible via datasource dropdown in all dashboards

---

## Consequences

### Positive
- ✅ Grafana pod stability (no more CrashLoopBackOff)
- ✅ Default dashboards work out-of-the-box (use Prometheus)
- ✅ Clear separation of concerns (metrics vs logs)
- ✅ Reduced cognitive load (users know default = metrics)

### Negative
- ⚠️ **Manual datasource selection**: Users must manually select Loki for log queries
- ⚠️ **Not intuitive for log-focused workflows**: Teams doing heavy log analysis need extra click
- ⚠️ **Dashboard creation**: New log dashboards must explicitly specify Loki datasource

### Mitigations
1. **Documentation**: README.md explains datasource strategy
2. **Dashboard templates**: Provide pre-configured log analysis dashboards with Loki selected
3. **Training**: Onboarding includes datasource selection demo
4. **Quick links**: Create bookmarks to common Loki queries

---

## Alternatives Considered

### Alternative 1: Loki as Default
**Rejected**: Logs are secondary to metrics in Kubernetes observability. Most users start with resource metrics (CPU, memory) before drilling into logs.

### Alternative 2: Separate Grafana Instances
```
grafana-metrics (Prometheus default) → Port 31968
grafana-logs (Loki default)         → Port 31969
```
**Rejected**: 
- Increases operational complexity (2 Grafana instances to maintain)
- Splits dashboards across instances (can't correlate metrics + logs easily)
- Higher resource usage (2x pods, 2x storage)

### Alternative 3: No Default Datasource
**Rejected**: 
- Breaks existing dashboards (require explicit datasource selection)
- Poor user experience (forces choice on every query)
- Not aligned with Grafana's UX patterns

### Alternative 4: Toggle Default via Feature Flag
**Rejected**: 
- Adds unnecessary complexity
- Doesn't solve the original problem (still need to choose one)
- Configuration drift risk between environments

---

## Implementation

### Phase 1: Immediate Fix (Completed 2026-01-18)
```bash
kubectl patch cm -n monitoring loki-loki-stack --type='json' \
  -p='[{"op": "replace", "path": "/data/loki-stack-datasource.yaml", 
  "value": "apiVersion: 1\ndatasources:\n- name: Loki\n  type: loki\n  
  access: proxy\n  url: \"http://loki:3100\"\n  version: 1\n  
  isDefault: false\n  jsonData:\n    {}\n"}]'
```

### Phase 2: Helm Values Override (Planned)
**File**: `helm-values/loki-stack-values.yaml`
```yaml
loki:
  enabled: true

promtail:
  enabled: true

grafana:
  enabled: false  # Using kube-prometheus-stack's Grafana

# Override datasource configuration
datasource:
  jsonData: "{}"
  uid: loki
  isDefault: false  # Explicit override
```

**Apply**:
```bash
helm upgrade loki grafana/loki-stack \
  -n monitoring \
  -f helm-values/loki-stack-values.yaml
```

---

## Compliance & Standards

### Industry Standards
- ✅ **Observability Best Practices**: Metrics-first, logs-second approach (SRE Workbook)
- ✅ **Grafana Recommendations**: Default datasource should be most frequently used
- ✅ **Kubernetes Observability**: Prometheus is de facto standard for k8s metrics

### Internal Standards
- ✅ **Separation of Concerns**: Metrics (operational) vs Logs (diagnostic)
- ✅ **Least Surprise Principle**: Default behavior matches user expectations
- ✅ **Performance**: Default datasource should have lowest latency

---

## Monitoring & Success Metrics

### Key Metrics
1. **Grafana Uptime**: Target 99.9% (was 0% for 135 days)
2. **Dashboard Load Time**: < 2 seconds for default dashboards
3. **User Complaints**: Zero complaints about datasource selection
4. **Loki Usage**: Track manual Loki datasource selections (should remain < 20% of queries)

### Alerts
```yaml
- alert: GrafanaDefaultDatasourceConflict
  expr: count(grafana_datasource_info{is_default="true"}) > 1
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Multiple default datasources detected"
```

---

## Review Schedule
- **Next Review**: 2026-04-18 (3 months)
- **Trigger for Review**: 
  - User complaints > 5/month about datasource selection
  - New observability tools added (e.g., Tempo for traces)
  - Grafana major version upgrade

---

## References
- **Incident**: [INC-2026-01-18-GRAFANA-CRASHLOOP](../incidents/INC-2026-01-18-grafana-crashloop.md)
- **Runbook**: [RB-001: Grafana Datasource Conflict](../runbooks/RB-001-grafana-datasource-conflict.md)
- **Grafana Docs**: https://grafana.com/docs/grafana/latest/datasources/
- **SRE Workbook**: Chapter 15 - Observability

---

## Metadata
- **Decision Date**: 2026-01-18
- **Deciders**: Platform Engineering Lead, SRE Lead
- **Stakeholders**: DevOps Team, Engineering Managers
- **Status**: Accepted & Implemented
- **Category**: Observability, Configuration
