# Proyecto 1: Hybrid DevSecOps Lab

## 📋 Resumen Ejecutivo

Plataforma base enterprise-like que simula un entorno híbrido real sin exposición a internet. Es la base estructural sobre la que se construyen todos los demás proyectos.

## 🎯 Objetivos

- Demostrar arquitectura realista adaptada a limitaciones de hardware
- - Implementar seguridad desde el diseño (Security-by-Design)
  - - Crear entorno reproducible para testing y demostración
    - - Proporcionar base para CI/CD y observabilidad
     
      - ## 🏗️ Arquitectura
     
      - ### Componentes Principales
     
      - ```
        ┌─────────────────────────────────────────────────────┐
        │         Host Proxmox (Bare Metal)                   │
        ├─────────────────────────────────────────────────────┤
        │  ┌──────────────┐  ┌──────────────┐  ┌───────────┐  │
        │  │ Control Plane│  │ Worker Node 1│  │ Ingress   │  │
        │  │   (k3s)      │  │   (k3s)      │  │ Controller│  │
        │  └──────────────┘  └──────────────┘  └───────────┘  │
        │         │                 │                  │        │
        │  ┌──────────────────────────────────────────────┐   │
        │  │  Networking (CNI - Flannel/Cilium)           │   │
        │  └──────────────────────────────────────────────┘   │
        │                                                      │
        │  ┌──────────────┐  ┌──────────────┐  ┌───────────┐  │
        │  │ Storage      │  │ Secrets Mgmt │  │ Logging   │  │
        │  │ (Local PV)   │  │ (Vault/SOPS) │  │ (Loki)    │  │
        │  └──────────────┘  └──────────────┘  └───────────┘  │
        │                                                      │
        │  ┌────────────────────────────────────────────────┐  │
        │  │  GitHub Actions Runner (Self-Hosted)           │  │
        │  └────────────────────────────────────────────────┘  │
        └─────────────────────────────────────────────────────┘
        ```

        ## 📚 Stack Tecnológico

        | Capa | Tecnología | Justificación |
        |------|-----------|---|
        | **Hipervisor** | Proxmox | Open Source, KVM-based, sin licencia |
        | **Orquestación** | k3s | Kubernetes ligero, ~500MB RAM vs 2GB+ de full K8s |
        | **Contenedores** | Docker | Estándar de facto |
        | **CI/CD** | GitHub Actions | Integrado, no requiere servidor separado |
        | **Versionado** | GitFlow | Enterprise standard |
        | **Secrets** | Vault / SOPS | Encriptación declarativa |
        | **Networking** | Flannel/Cilium | CNI ligera pero funcional |
        | **Storage** | Local PV | Suficiente para lab, escalable a Ceph |

        ## ⚙️ Por Qué k3s y No OpenShift

        ### Análisis de Decisión (ADR-001)

        **Decisión**: Usar k3s en lugar de OpenShift

        **Contexto**
        - Hardware limitado (homelab ~32GB RAM)
        - - OpenShift mínimo: 4 nodos, 16GB RAM por nodo
          - - k3s mínimo: 1 nodo, 512MB RAM
           
            - **Alternativas Consideradas**
            - 1. **OpenShift Full**: Enterprise-grade, pero overkill y costos
              2. 2. **Minikube**: Single node, no realista para arquitectura multi-nodo
                 3. 3. **k3s**: Lightweight Kubernetes, compatible con manifiestos K8s
                   
                    4. **Decisión**
                    5. - **Usar k3s** con instalación multi-nodo
                       - - Justifica arquitectura cloud-agnóstica
                         - - Demuestra comprensión de trade-offs
                          
                           - **Implicaciones**
                           - - ✅ Testing realista de multi-nodo
                             - - ✅ Bajo footprint de recursos
                               - - ⚠️ No incluye Red Hat Enterprise Features
                                 - - ⚠️ Pero demostramos que los manifiestos son portables a OpenShift/EKS/AKS
                                  
                                   - ## 🔐 Seguridad por Diseño
                                  
                                   - ### Principios
                                  
                                   - 1. **Defense in Depth**: Múltiples capas de seguridad
                                     2. 2. **Least Privilege**: Mínimos permisos necesarios
                                        3. 3. **Encryption at Rest and in Transit**: SIEMPRE
                                           4. 4. **Auditing**: Todo se registra y se monitoriza
                                              5. 5. **Network Segmentation**: VLANs/Network Policies
                                                
                                                 6. ### Implementación
                                                
                                                 7. ```yaml
                                                    # Ejemplo: NetworkPolicy en k3s
                                                    apiVersion: networking.k8s.io/v1
                                                    kind: NetworkPolicy
                                                    metadata:
                                                      name: deny-all-default
                                                    spec:
                                                      podSelector: {}
                                                      policyTypes:
                                                      - Ingress
                                                      - Egress
                                                    # Luego, permitir explícitamente lo necesario
                                                    ```

                                                    ## 📦 Estructura de Carpetas

                                                    ```
                                                    01-hybrid-devsecops-lab/
                                                    ├── README.md (este archivo)
                                                    ├── docs/
                                                    │   ├── architecture.md          # Arquitectura detallada
                                                    │   ├── setup-guide.md           # Guía de instalación paso a paso
                                                    │   ├── security-policies.md     # Políticas de seguridad
                                                    │   └── troubleshooting.md       # Resolución de problemas
                                                    ├── diagrams/
                                                    │   ├── c4-context.drawio        # C4 - Contexto
                                                    │   ├── c4-containers.drawio     # C4 - Contenedores
                                                    │   ├── c4-components.drawio     # C4 - Componentes
                                                    │   └── network-topology.drawio  # Topología de red
                                                    ├── adrs/
                                                    │   ├── ADR-001-k3s-over-openshift.md
                                                    │   ├── ADR-002-networking-cni-choice.md
                                                    │   ├── ADR-003-secret-management.md
                                                    │   └── ADR-004-storage-strategy.md
                                                    ├── manifests/
                                                    │   ├── base/                    # Configuración base
                                                    │   │   ├── namespaces.yaml
                                                    │   │   ├── rbac.yaml
                                                    │   │   └── network-policies.yaml
                                                    │   ├── apps/                    # Aplicaciones de ejemplo
                                                    │   │   ├── app-a-deployment.yaml
                                                    │   │   ├── app-b-deployment.yaml
                                                    │   │   └── kustomization.yaml
                                                    │   └── overlays/                # Customizaciones por entorno
                                                    │       ├── development/
                                                    │       ├── staging/
                                                    │       └── production/
                                                    ├── scripts/
                                                    │   ├── provision-cluster.sh     # Setup inicial
                                                    │   ├── install-vault.sh         # Instalación de Vault
                                                    │   ├── install-observability.sh # Prometheus, Loki, Grafana
                                                    │   └── verify-setup.sh          # Validación del setup
                                                    └── Terraform/ (Opcional)
                                                        ├── main.tf                  # Infraestructura como código
                                                        ├── variables.tf
                                                        └── outputs.tf
                                                    ```

                                                    ## 🚀 Inicio Rápido

                                                    ### Requisitos Previos

                                                    - Proxmox instalado en servidor bare metal
                                                    - - Mínimo 4 CPUs y 16GB RAM (recomendado 32GB)
                                                      - - Red aislada (sin acceso a internet de los nodos)
                                                        - - SSH acceso a host Proxmox
                                                         
                                                          - ### Instalación (Resumen)
                                                         
                                                          - ```bash
                                                            # 1. Crear VMs en Proxmox (3 nodos: 1 control-plane, 2 workers)
                                                            bash scripts/provision-cluster.sh

                                                            # 2. Instalar k3s cluster
                                                            # (Ver docs/setup-guide.md para detalles)

                                                            # 3. Instalar componentes de seguridad
                                                            bash scripts/install-vault.sh

                                                            # 4. Desplegar aplicaciones de ejemplo
                                                            kubectl apply -k manifests/overlays/development

                                                            # 5. Verificar setup
                                                            bash scripts/verify-setup.sh
                                                            ```

                                                            ## 📊 Diagrama C4

                                                            ### Nivel 1: Contexto
                                                            ```
                                                            ┌─────────────┐
                                                            │  Developer  │
                                                            └─────────────┘
                                                                   │
                                                                   ├─→ git push
                                                                   │
                                                                   └─→ SSH Management
                                                                          │
                                                                          ▼
                                                                   ┌──────────────────┐
                                                                   │  Hybrid Cluster  │
                                                                   │  (Proxmox + k3s) │
                                                                   └──────────────────┘
                                                                          │
                                                                          ├─→ Container Workloads
                                                                          ├─→ Security Policies
                                                                          └─→ Observability
                                                            ```

                                                            (Ver `diagrams/` para diagramas C4 completos en DrawIO format)

                                                            ## 🧪 Testing & Validación

                                                            ### Criterios de Aceptación

                                                            - ✅ Cluster k3s con 3+ nodos funcional
                                                            - - ✅ DNS resolving para namespaces
                                                              - - ✅ Network policies aplicadas
                                                                - - ✅ Vault o SOPS funcional para secrets
                                                                  - - ✅ Logs centralizados en Loki
                                                                    - - ✅ Métricas en Prometheus
                                                                      - - ✅ Acceso al dashboard via Grafana
                                                                       
                                                                        - ### Comandos de Validación
                                                                       
                                                                        - ```bash
                                                                          # Verificar nodos
                                                                          kubectl get nodes

                                                                          # Verificar namespaces
                                                                          kubectl get ns

                                                                          # Verificar network policies
                                                                          kubectl get networkpolicies -A

                                                                          # Verificar pods running
                                                                          kubectl get pods -a
                                                                          ```

                                                                          ## 🔄 Integración con Otros Proyectos

                                                                          - **Proyecto 2 (CI/CD)**: Esta plataforma es el target de deploy
                                                                          - - **Proyecto 3 (Observabilidad)**: Prometheus/Loki/Grafana corren aquí
                                                                            - - **Proyecto 4 (Automatización)**: n8n monitores el estado de este cluster
                                                                             
                                                                              - ## 📚 Documentación Relacionada
                                                                             
                                                                              - - [ARCHITECTURE_OVERVIEW.md](../ARCHITECTURE_OVERVIEW.md) - Visión general del portfolio
                                                                                - - [setup-guide.md](./docs/setup-guide.md) - Instalación paso a paso
                                                                                  - - [ADRs](./adrs/) - Decisiones arquitectónicas justificadas
                                                                                   
                                                                                    - ## 🤝 Contribuciones
                                                                                   
                                                                                    - Las mejoras son bienvenidas. Por favor:
                                                                                    - 1. Abrir issue describiendo cambio
                                                                                      2. 2. Crear branch `feature/descripcion`
                                                                                         3. 3. Incluir tests
                                                                                            4. 4. Actualizar documentación
                                                                                              
                                                                                               5. ## 📝 License
                                                                                              
                                                                                               6. Apache 2.0 (heredado del repositorio principal)
