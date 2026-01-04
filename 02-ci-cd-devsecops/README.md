# Proyecto 2: CI/CD DevSecOps Pipeline

## 📋 Resumen Ejecutivo

Pipeline CI/CD enterprise-grade que implementa DevSecOps práctico con gates de seguridad en cada stage. Demuestra capacidad de estandarización y gestión de riesgo (ISX).

## 🎯 Objetivos

- Implementar pipeline multi-stage con gates de seguridad
- - Automatizar testing, análisis y deployes
  - - Demostrar compliance y auditabilidad
    - - Servir como estándar para NTT Data
     
      - ## 🔄 Stages del Pipeline
     
      - ```
        ┌──────────────────────────────────────────────────────────────────┐
        │                    GitHub Actions Workflow                       │
        ├──────────────────────────────────────────────────────────────────┤
        │                                                                  │
        │  1. TRIGGER (PR/Push to main)                                   │
        │     └─→ On: pull_request, push                                  │
        │                                                                  │
        │  2. BUILD                                                        │
        │     └─→ Compile code                                            │
        │     └─→ Run unit tests                                          │
        │     └─→ Generate coverage reports                               │
        │                                                                  │
        │  3. SAST (Static Application Security Testing)                  │
        │     └─→ SonarQube analysis                                      │
        │     └─→ Trivy code scanning                                     │
        │     └─→ Dependency check                                        │
        │     └─→ GATE: Min coverage threshold                            │
        │                                                                  │
        │  4. CONTAINER BUILD                                             │
        │     └─→ Build Docker image                                      │
        │     └─→ Push to registry                                        │
        │     └─→ Sign image (Cosign)                                     │
        │                                                                  │
        │  5. CONTAINER SCAN                                              │
        │     └─→ Trivy image scan                                        │
        │     └─→ Check for HIGH/CRITICAL CVEs                           │
        │     └─→ GATE: Max severity threshold                            │
        │                                                                  │
        │  6. INTEGRATION TESTS                                           │
        │     └─→ Deploy to staging cluster                               │
        │     └─→ Run smoke tests                                         │
        │     └─→ Run security tests                                      │
        │                                                                  │
        │  7. COMPLIANCE GATE                                             │
        │     └─→ Check security policies                                 │
        │     └─→ Validate configurations                                 │
        │     └─→ GATE: Policy compliance required                        │
        │                                                                  │
        │  8. APPROVAL (Manual for Production)                            │
        │     └─→ Slack/Teams notification                                │
        │     └─→ Manual review required                                  │
        │     └─→ Audit log created                                       │
        │                                                                  │
        │  9. DEPLOY                                                       │
        │     └─→ Deploy to production (Proyecto 1)                       │
        │     └─→ Blue-green/Canary strategy                              │
        │     └─→ Health checks                                           │
        │                                                                  │
        │  10. POST-DEPLOY                                                │
        │      └─→ Smoke tests                                            │
        │      └─→ Update metrics                                         │
        │      └─→ Notify team                                            │
        │                                                                  │
        └──────────────────────────────────────────────────────────────────┘
        ```

        ## 📚 Stack Técnico

        | Componente | Tool | Razón |
        |---|---|---|
        | **CI/CD** | GitHub Actions | Integrado, sin servidor externo |
        | **Build** | Maven/Gradle | Estándar enterprise |
        | **Testing** | JUnit5 + Cucumber | BDD framework |
        | **SAST** | SonarQube Community | Code quality + security |
        | **Container Scan** | Trivy | Ligero, rápido, sin requisitos |
        | **Image Signing** | Cosign | Supply chain security |
        | **Artifact Storage** | GitHub Container Registry | Integrado |
        | **Deployment** | kubectl/Helm | Estándar Kubernetes |

        ## 📂 Estructura

        ```
        02-ci-cd-devsecops/
        ├── README.md
        ├── .github/
        │   └── workflows/
        │       ├── build.yml              # Build + Test + SAST
        │       ├── container.yml          # Container build + scan
        │       ├── security-gates.yml     # Compliance checks
        │       └── deploy.yml             # Deploy to k3s cluster
        ├── src/
        │   ├── main/java/
        │   └── test/java/
        ├── Dockerfile                      # Multi-stage build
        ├── sonar-project.properties        # SonarQube config
        ├── .trivyignore                    # Trivy vulnerability config
        ├── policies/
        │   ├── security-policy.rego        # OPA/Rego policies
        │   └── compliance-rules.yaml       # Custom rules
        ├── helm/                           # Helm charts
        │   ├── Chart.yaml
        │   └── values.yaml
        └── scripts/
            ├── scan-image.sh
            ├── deploy.sh
            └── verify-gates.sh
        ```

        ## 🔐 Gates de Seguridad Explicados

        ### GATE 1: Code Coverage
        ```yaml
        Threshold: >= 80%
        Fail-fast: Si < 80%, bloquea el pipeline
        Objetivo: Garantizar testing suficiente
        ```

        ### GATE 2: SAST Vulnerabilities
        ```yaml
        Allowed:
          - INFO: unlimited
          - MINOR: <= 5
          - MAJOR: 0
          - CRITICAL: 0
        Fail-fast: Si hay CRITICAL, bloquea
        ```

        ### GATE 3: Container Vulnerabilities
        ```yaml
        Allowed:
          - INFO: unlimited
          - MINOR: unlimited
          - MAJOR: <= 3
          - CRITICAL: 0
        Fail-fast: Si hay CRITICAL, bloquea
        ```

        ### GATE 4: Compliance
        ```yaml
        Checks:
          - Network policies configured: YES
          - RBAC configured: YES
          - Resource limits set: YES
          - Security context set: YES
        Fail-fast: Si algo falla
        ```

        ## 🚀 Ejemplo: Flujo de PR

        ```bash
        # Developer crea rama
        git checkout -b feature/new-api

        # Hace cambios, pushea
        git push origin feature/new-api

        # ← GITHUB ACTIONS TRIGGER
        #   1. Build        [✓]
        #   2. Unit Tests   [✓ 85% coverage]
        #   3. SAST         [✓ 2 MINOR issues, < 5 allowed]
        #   4. Container    [✓]
        #   5. Scan Image   [✓ No CRITICAL CVEs]
        #   6. Int Tests    [✓]
        #   7. Compliance   [✓]
        # → GATES PASSED

        # ← Developer abre PR
        # ← Team reviews code
        # ← Merge approved
        # → Code to main branch

        # ← AUTOMATIC DEPLOY (Staging)
        # → Smoke tests pass
        # → Manual approval required (for production)
        # → Slack message: "Ready to deploy to production"
        # → Team approves (3 people required)
        # → AUTOMATIC DEPLOY (Production)
        ```

        ## 📊 Métricas & Reporting

        ### Dashboard Disponible
        - Build success rate
        - - Code coverage trends
          - - Security findings over time
            - - Deployment frequency
              - - Lead time
                - - MTTR (Mean Time To Recovery)
                 
                  - ## 🧪 Validación
                 
                  - Criterios de aceptación:
                  - - ✅ Pipeline ejecuta en < 10 minutos
                    - - ✅ Todos los gates funcionales
                      - - ✅ Manual approval requerido para prod
                        - - ✅ Audit log de todos los deploys
                          - - ✅ Rollback automático si smoke tests fallan
                           
                            - ## 🔄 Integración con Otros Proyectos
                           
                            - - **Proyecto 1**: Target de deployment (k3s cluster)
                              - - **Proyecto 3**: Observabilidad del pipeline (métricas, logs)
                                - - **Proyecto 4**: Alertas automáticas en n8n
                                 
                                  - ## 📚 Referencia
                                 
                                  - - [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides)
                                    - - [OWASP DevSecOps](https://owasp.org/)
                                      - - [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
