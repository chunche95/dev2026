#!/bin/bash
#
# Script: 01-diagnosis.sh
# Purpose: Backup and diagnose Grafana CrashLoopBackOff issue
# Author: Paulino
# Date: 2026-01-18
#

set -e  # Exit on error

BACKUP_DIR=~/cluster-audit/observability
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=================================================="
echo "  Grafana CrashLoopBackOff - Diagnosis Script"
echo "=================================================="
echo ""

# Create backup directory
mkdir -p ${BACKUP_DIR}

# 1. Backup Loki datasource ConfigMap
echo "=== 1. Backing up Loki datasource ConfigMap ==="
kubectl get cm -n monitoring loki-loki-stack -o yaml \
  > ${BACKUP_DIR}/loki-datasource-BACKUP-${TIMESTAMP}.yaml

echo "✅ Backup saved: ${BACKUP_DIR}/loki-datasource-BACKUP-${TIMESTAMP}.yaml"
echo ""

# 2. Backup Prometheus datasource ConfigMap  
echo "=== 2. Backing up Prometheus datasource ConfigMap ==="
kubectl get cm -n monitoring monitorgrafana-kube-promet-grafana-datasource -o yaml \
  > ${BACKUP_DIR}/prometheus-datasource-BACKUP-${TIMESTAMP}.yaml

echo "✅ Backup saved: ${BACKUP_DIR}/prometheus-datasource-BACKUP-${TIMESTAMP}.yaml"
echo ""

# 3. Get Grafana pod status
echo "=== 3. Current Grafana Pod Status ==="
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
echo ""

# 4. Check datasource configurations
echo "=== 4. Loki Datasource Configuration ==="
kubectl get cm -n monitoring loki-loki-stack -o yaml | grep -A 3 "isDefault"
echo ""

echo "=== 5. Prometheus Datasource Configuration ==="
kubectl get cm -n monitoring monitorgrafana-kube-promet-grafana-datasource -o yaml | grep -A 3 "isDefault"
echo ""

# 6. Get pod logs
echo "=== 6. Grafana Pod Logs (last 50 lines) ==="
POD_NAME=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n monitoring ${POD_NAME} -c grafana --tail=50 \
  > ${BACKUP_DIR}/grafana-logs-${TIMESTAMP}.txt

echo "✅ Logs saved: ${BACKUP_DIR}/grafana-logs-${TIMESTAMP}.txt"
echo ""

echo "=================================================="
echo "  Diagnosis Complete"
echo "=================================================="
echo "Backups location: ${BACKUP_DIR}"
echo ""
echo "Next step: Run 02-fix.sh to apply the solution"
