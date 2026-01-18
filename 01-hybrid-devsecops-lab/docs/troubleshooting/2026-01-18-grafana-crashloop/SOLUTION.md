# Solution Implementation: Grafana CrashLoopBackOff

**Incident ID**: `GRAFANA-CRASHLOOP-2026-01-18`  
**Implemented By**: Paulino  
**Date**: 2026-01-18  
**Status**: ✅ RESOLVED  

---

## Solution Overview

**Problem**: Two datasources marked as `isDefault: true` causing Grafana to crash.

**Solution**: Change Loki datasource to `isDefault: false`, keeping Prometheus as default.

**Rationale**:
- **Prometheus**: Primary datasource for cluster-wide metrics and default dashboards
- **Loki**: Secondary datasource for log aggregation, used in specialized dashboards
- Users can manually select Loki datasource when needed for log analysis

---

## Implementation Steps

### Step 1: Backup Configuration

**Purpose**: Preserve original state for rollback if needed.

**Script**: `scripts/01-diagnosis.sh`

```bash
#!/bin/bash
# Backup original ConfigMap before modification

BACKUP_DIR=~/cluster-audit/observability
mkdir -p ${BACKUP_DIR}

echo "=== Backing up Loki datasource ConfigMap ==="
kubectl get cm -n monitoring loki-loki-stack -o yaml \
  > ${BACKUP_DIR}/loki-datasource-BACKUP-$(date +%Y%m%d-%H%M%S).yaml

echo "✅ Backup saved to ${BACKUP_DIR}"
```

**Execution**:
```bash
chmod +x scripts/01-diagnosis.sh
./scripts/01-diagnosis.sh
```

**Output**:
```
=== Backing up Loki datasource ConfigMap ===
✅ Backup saved to ~/cluster-audit/observability
```

---

### Step 2: Verify Current Configuration

**Purpose**: Confirm which datasources are marked as default.

**Commands**:
```bash
echo "=== Checking Loki datasource ==="
kubectl get cm -n monitoring loki-loki-stack -o yaml | grep -A 2 "isDefault"

echo "=== Checking Prometheus datasource ==="
kubectl get cm -n monitoring monitorgrafana-kube-promet-grafana-datasource -o yaml \
  | grep -A 2 "isDefault"
```

**Output**:
```
=== Checking Loki datasource ===
  isDefault: true  # ❌ CONFLICT

=== Checking Prometheus datasource ===
  isDefault: true  # ❌ CONFLICT
```

---

### Step 3: Apply Fix

**Purpose**: Patch Loki ConfigMap to set `isDefault: false`.

**Script**: `scripts/02-fix.sh`

```bash
#!/bin/bash
# Patch Loki datasource ConfigMap

echo "=== Patching Loki datasource ConfigMap ==="
kubectl patch cm -n monitoring loki-loki-stack --type='json' \
  -p='[{"op": "replace", "path": "/data/loki-stack-datasource.yaml", 
  "value": "apiVersion: 1\ndatasources:\n- name: Loki\n  type: loki\n  access: proxy\n  url: \"http://loki:3100\"\n  version: 1\n  isDefault: false\n  jsonData:\n    {}\n"}]'

if [ $? -eq 0 ]; then
    echo "✅ ConfigMap patched successfully"
else
    echo "❌ Failed to patch ConfigMap"
    exit 1
fi

echo ""
echo "=== Verifying patch ==="
kubectl get cm -n monitoring loki-loki-stack -o yaml | grep -A 2 "isDefault"
```

**Execution**:
```bash
chmod +x scripts/02-fix.sh
./scripts/02-fix.sh
```

**Output**:
```
=== Patching Loki datasource ConfigMap ===
configmap/loki-loki-stack patched
✅ ConfigMap patched successfully

=== Verifying patch ===
  isDefault: false  # ✅ FIXED
```

---

### Step 4: Trigger Pod Restart

**Purpose**: Delete crashed pod to force Kubernetes to create new pod with updated config.

**Commands**:
```bash
echo "=== Deleting crashed Grafana pod ==="
kubectl delete pod -n monitoring monitorgrafana-677d8d6465-tktwr

echo "=== Waiting for new pod creation ==="
sleep 15

echo "=== Checking new pod status ==="
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
```

**Output**:
```
=== Deleting crashed Grafana pod ===
pod "monitorgrafana-677d8d6465-tktwr" deleted

=== Checking new pod status ===
NAME                              READY   STATUS    RESTARTS   AGE
monitorgrafana-677d8d6465-sfz69   3/3     Running   0          96s
```

**Observation**: New pod `sfz69` created, all 3 containers Running, 0 restarts.

---

### Step 5: Validation

**Purpose**: Verify Grafana is fully operational.

**Script**: `scripts/03-validation.sh`

```bash
#!/bin/bash
# Validate Grafana fix

echo "=== 1. Pod Status Check ==="
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

echo ""
echo "=== 2. Restart Count Check ==="
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana | grep "Restart Count"

echo ""
echo "=== 3. HTTP Endpoint Check ==="
curl -I http://192.168.0.18:31968

echo ""
echo "=== 4. Pod Logs Check (last 20 lines) ==="
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana --tail=20

echo ""
echo "=== 5. Datasource Validation ==="
kubectl get cm -n monitoring loki-loki-stack -o yaml | grep "isDefault"
kubectl get cm -n monitoring monitorgrafana-kube-promet-grafana-datasource -o yaml | grep "isDefault"
```

**Execution**:
```bash
chmod +x scripts/03-validation.sh
./scripts/03-validation.sh
```

**Results**:

✅ **Pod Status**: `3/3 Running`
```
NAME                              READY   STATUS    RESTARTS   AGE
monitorgrafana-677d8d6465-sfz69   3/3     Running   0          96s
```

✅ **Restart Count**: `0` (all 3 containers)
```
Restart Count:   0
Restart Count:   0
Restart Count:   0
```

✅ **HTTP Endpoint**: `302 Found` (redirecting to `/login` - expected)
```
HTTP/1.1 302 Found
Location: /login
```

✅ **Pod Logs**: No errors, server listening
```
logger=http.server msg="HTTP Server Listen" address=[::]:3000 protocol=http
```

✅ **Datasource Configuration**:
```
# Loki
isDefault: false  ✅

# Prometheus  
isDefault: true   ✅
```

---

## Success Criteria

| Criterion | Expected | Actual | Status |
|-----------|----------|--------|--------|
| Pod Running | 3/3 | 3/3 | ✅ |
| Restart Count | 0 | 0 | ✅ |
| HTTP Status | 302 | 302 | ✅ |
| Loki Default | false | false | ✅ |
| Prometheus Default | true | true | ✅ |
| Error Logs | None | None | ✅ |

---

## Rollback Plan

If solution fails, rollback procedure:

```bash
# Restore original ConfigMap
kubectl apply -f ~/cluster-audit/observability/loki-datasource-BACKUP-*.yaml

# Delete pod to trigger restart
kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana

# Wait and verify
sleep 15
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
```

**Note**: Rollback would restore CrashLoopBackOff state. Only use if new issue introduced.

---

## Post-Implementation

### Configuration Changes
- ✅ Loki datasource: `isDefault: false`
- ✅ Prometheus datasource: `isDefault: true` (unchanged)

### Operational Impact
- ✅ Grafana dashboard accessible at `http://192.168.0.18:31968`
- ✅ Default datasource = Prometheus (metrics-focused dashboards work)
- ℹ️ Log dashboards require manual datasource selection (Loki)

### Documentation Updated
- ✅ Incident report created
- ✅ Root cause analysis documented
- ✅ Solution steps recorded
- ⏳ ADR pending for architectural decision
- ⏳ Runbook pending for future reference

---

## Time Breakdown

| Phase | Duration |
|-------|----------|
| Diagnosis | 5 minutes |
| Root Cause Analysis | 3 minutes |
| Solution Implementation | 2 minutes |
| Validation | 2 minutes |
| **Total** | **12 minutes** |

**Note**: Incident had 135-day impact duration due to late detection, but actual resolution was <15 minutes.

---

## Related Documents

- **Incident Report**: `INCIDENT.md`
- **Root Cause Analysis**: `ROOT_CAUSE_ANALYSIS.md`
- **Evidence**: `./evidence/`
- **Scripts**: `./scripts/`
