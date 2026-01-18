# Auditoría del Cluster k3s - 2026-01-18 21:46:11

## Cluster Info
- **Fecha auditoría**: 2026-01-18 21:46:11
- **Usuario**: pau1
- **Hostname**: debianmaster

## Nodos
```
NAME            STATUS   ROLES                  AGE    VERSION        INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION   CONTAINER-RUNTIME
debianmaster    Ready    control-plane,master   309d   v1.31.6+k3s1   192.168.0.18   <none>        Debian GNU/Linux 12 (bookworm)   6.1.0-40-amd64   containerd://2.0.2-k3s2
debianworker1   Ready    worker                 74d    v1.33.5+k3s1   192.168.0.24   <none>        Debian GNU/Linux 12 (bookworm)   6.1.0-40-amd64   containerd://2.1.4-k3s1
debianworker2   Ready    worker                 309d   v1.33.5+k3s1   192.168.0.25   <none>        Debian GNU/Linux 12 (bookworm)   6.1.0-40-amd64   containerd://2.1.4-k3s1
```

## Versiones
```
Client Version: v1.32.3
Kustomize Version: v5.5.0
Server Version: v1.31.6+k3s1
```

## Namespaces
```
NAME                   STATUS   AGE
argocd                 Active   141d
cyclops                Active   74d
default                Active   309d
headlamp               Active   141d
kube-node-lease        Active   309d
kube-public            Active   309d
kube-system            Active   309d
kubernetes-dashboard   Active   156d
monitoring             Active   308d
pauhome                Active   308d
```

## Workloads Running
- **Pods**: 42
- **Deployments**: 22
- **DaemonSets**: 4
- **StatefulSets**: 4

## Storage
- **Persistent Volumes**: 0
- **Persistent Volume Claims**: 0
- **Storage Classes**: 1

## Seguridad
- **Network Policies**: 9
- **Secrets**: 32

---
**Archivos generados**: 32

**Estructura de directorios**:
```
/home/pau1/cluster-audit
/home/pau1/cluster-audit/{nodes,namespaces,workloads,networking,security,storage,observability}
/home/pau1/cluster-audit/namespaces
/home/pau1/cluster-audit/observability
/home/pau1/cluster-audit/config
/home/pau1/cluster-audit/nodes
/home/pau1/cluster-audit/security
/home/pau1/cluster-audit/workloads
/home/pau1/cluster-audit/networking
/home/pau1/cluster-audit/storage
```
