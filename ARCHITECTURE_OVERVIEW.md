# Architecture Overview - dev2026 Portfolio

## Visión General

Este repositorio presenta un portfolio de arquitectura de soluciones (ISA - Innovation Solutions Architect) diseñado para demostrar capacidades profesionales transferibles a mercados europeos, estadounidenses y japoneses.

**Objetivo**: Conectar negocio, riesgo, coste y tecnología a través de 4 proyectos interdependientes que simulan escenarios empresariales reales.

---

## 🎯 Estrategia de Posicionamiento

### Capas Profesionales Demostradas

- **ISE (Ingeniero)**: Diseño y ejecución técnica
- - **ISX (Experto)**: Selección técnica justificada, gestión de riesgo
  - - **ISA (Arquitecto)**: Toma de decisiones conectada a negocio y estrategia
   
    - ### Mercados Objetivo
   
    - - 🇪🇺 **Europa**: Compliance, arquitectura realista, documentación rigurosa
      - - 🇺🇸 **EEUU**: DevSecOps, cloud híbrido, automatización
        - - 🇯🇵 **Japón**: Procesos formales, documentación exhaustiva, calidad técnica
         
          - ---

          ## 📦 Estructura de Proyectos

          ```
          dev2026/
          ├── 01-hybrid-devsecops-lab/          # CORE - Plataforma Base
          │   ├── docs/
          │   ├── diagrams/
          │   ├── adrs/
          │   └── README.md
          ├── 02-ci-cd-devsecops/               # Pipeline Profesional
          │   ├── workflows/
          │   ├── policies/
          │   └── README.md
          ├── 03-observability-foundation/       # Stack Observabilidad
          │   ├── prometheus/
          │   ├── loki/
          │   ├── grafana/
          │   └── README.md
          ├── 04-n8n-automation/                # Automatización + IA
          │   ├── workflows/
          │   ├── ai-integration/
          │   └── README.md
          └── ARCHITECTURE_OVERVIEW.md
          ```

          ---

          ## 🚀 Proyectos

          ### PROYECTO 1: Hybrid DevSecOps Lab (MÁXIMA PRIORIDAD)

          **Propósito**: Plataforma base enterprise-like que simula cliente real sin exposición a internet.

          **Stack Tecnológico**
          - Proxmox (virtualización)
          - - k3s (Kubernetes ligero - justificado por hardware)
            - - Docker (contenedores)
              - - GitHub Actions (CI/CD)
                - - GitFlow (versionado)
                  - - Vault/SOPS (secretos - opcional)
                   
                    - **Qué Demuestra**
                    - - Pensamiento arquitectónico realista
                      - - Adaptabilidad (OpenShift → k3s)
                        - - Diseño cloud-agnóstico
                          - - Security-by-design
                           
                            - **Entregables**
                            - - Diagrama C4 (contexto, contenedores, componentes)
                              - - Architecture Decision Records (ADRs)
                                - - README para manager (ejecutivo)
                                  - - README para ingeniero (técnico)
                                   
                                    - ---

                                    ### PROYECTO 2: CI/CD DevSecOps (MUY ALTA PRIORIDAD)

                                    **Propósito**: Pipeline enterprise-grade con gates de seguridad reales.

                                    **Stages**
                                    1. Build (compilación)
                                    2. 2. Test (unit + integration)
                                       3. 3. SAST (análisis estático)
                                          4. 4. Scan de contenedores (vulnerabilidades)
                                             5. 5. Policy gate (compliance)
                                                6. 6. Deploy (condicionado)
                                                  
                                                   7. **Qué Demuestra**
                                                   8. - DevSecOps real en producción
                                                      - - Mentalidad ISX: riesgo y compliance
                                                        - - Estandarización (clave en NTT Data)
                                                         
                                                          - **No Reinventar**
                                                          - - Usar herramientas estándar y soportadas
                                                            - - Justificar cada decisión técnica
                                                             
                                                              - ---

                                                              ### PROYECTO 3: Observabilidad Foundation (MEDIA-ALTA PRIORIDAD)

                                                              **Propósito**: Stack observabilidad integrado, orientado a decisiones, no a dashboards.

                                                              **Stack**
                                                              - Prometheus (métricas)
                                                              - - Loki (logs)
                                                                - - Grafana (visualización)
                                                                 
                                                                  - **Enfoque Arquitectónico**
                                                                  - - NO convertirse en "ingeniero de Grafana"
                                                                    - - Observabilidad como capacidad transversal
                                                                      - - Integrada en Proyecto 1
                                                                        - - Responder 3 preguntas clave:
                                                                          -   - ¿Qué se mide?
                                                                              -   - ¿Por qué?
                                                                                  -   - ¿Qué decisión permite tomar?
                                                                                   
                                                                                      - **Evitar**
                                                                                      - - Dashboards infinitos
                                                                                        - - Métricas sin propósito
                                                                                          - - Overengineering
                                                                                           
                                                                                            - ---

                                                                                            ### PROYECTO 4: Automatización Inteligente n8n + IA (MEDIA PRIORIDAD)

                                                                                            **Propósito**: Diferenciador internacional. IA como capacidad auxiliar, no como producto.

                                                                                            **Casos de Uso Realistas**
                                                                                            - Monitorización estado infraestructura (router, latencia, batería)
                                                                                            - - Detección anomalías simples
                                                                                              - - Notificaciones (Telegram, Mail)
                                                                                                - - Clasificación y resumen con IA
                                                                                                 
                                                                                                  - **Criterio de IA**
                                                                                                  - - IA solo donde aporta valor real
                                                                                                    - - Consumo de tokens controlado y documentado
                                                                                                      - - Explícito: dónde sí, dónde no, por qué
                                                                                                       
                                                                                                        - **Evitar**
                                                                                                        - - Agentes IA por postureo
                                                                                                          - - Automatizaciones inútiles
                                                                                                            - - Consumo no controlado
                                                                                                             
                                                                                                              - ---
                                                                                                              
                                                                                                              ## 🧠 Uso de MCPs e IA
                                                                                                              
                                                                                                              **Regla de Oro**: IA como herramienta auxiliar, no como solución.
                                                                                                              
                                                                                                              **Dónde Usar**
                                                                                                              - Generación automática de documentación
                                                                                                              - - Análisis de logs y patrones
                                                                                                                - - Asistencia en toma de decisiones
                                                                                                                  - - Generación y validación de tests
                                                                                                                   
                                                                                                                    - **Dónde NO**
                                                                                                                    - - Decisiones arquitectónicas sin análisis humano
                                                                                                                      - - Ejecución de código sin validación
                                                                                                                        - - Sustitución de profesionales
                                                                                                                         
                                                                                                                          - **Documentación Explícita**
                                                                                                                          - Cada proyecto especifica:
                                                                                                                          - - Dónde se usa IA
                                                                                                                            - - Dónde no
                                                                                                                              - - Justificación
                                                                                                                               
                                                                                                                                - ---
                                                                                                                                
                                                                                                                                ## 🏗️ Principios Arquitectónicos
                                                                                                                                
                                                                                                                                ### No Dogmático, Pragmático
                                                                                                                                
                                                                                                                                - **Monolito central** (hexagonal) para cohesión
                                                                                                                                - - **Módulos desacoplados** para flexibilidad
                                                                                                                                  - - **Contenedores cuando aportan valor** (no por defecto)
                                                                                                                                    - - **Microservicios si y solo si** la complejidad lo justifica
                                                                                                                                      - - **Cloud-agnóstico**: AWS/Azure como diseño, no como herramienta
                                                                                                                                       
                                                                                                                                        - ### Enterprise-Ready
                                                                                                                                       
                                                                                                                                        - - Seguridad desde el diseño (Security-by-Design)
                                                                                                                                          - - Compliance incorporado
                                                                                                                                            - - Documentación exhaustiva
                                                                                                                                              - - Procesos formales (GitFlow, ADRs, C4)
                                                                                                                                               
                                                                                                                                                - ---
                                                                                                                                                
                                                                                                                                                ## 📊 Matriz de Impacto por Mercado
                                                                                                                                                
                                                                                                                                                | Competencia | Europa | EEUU | Japón |
                                                                                                                                                |---|---|---|---|
                                                                                                                                                | Arquitectura/Diseño | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
                                                                                                                                                | DevSecOps | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
                                                                                                                                                | Compliance | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
                                                                                                                                                | Documentación | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
                                                                                                                                                | Procesos Formales | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
                                                                                                                                                | Automatización | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
                                                                                                                                                
                                                                                                                                                ---
                                                                                                                                                
                                                                                                                                                ## 🎓 Cómo Usar Este Portfolio
                                                                                                                                                
                                                                                                                                                ### Para Manager / Mentor
                                                                                                                                                
                                                                                                                                                1. Leer README "manager" de cada proyecto (5 min cada uno)
                                                                                                                                                2. 2. Entender decisiones arquitectónicas via ADRs
                                                                                                                                                   3. 3. Ver diagrama C4 para contexto visual
                                                                                                                                                     
                                                                                                                                                      4. ### Para Technical Interviewer
                                                                                                                                                     
                                                                                                                                                      5. 1. Revisar decisiones en ADRs (justificación)
                                                                                                                                                         2. 2. Analizar trade-offs en arquitectura
                                                                                                                                                            3. 3. Evaluar enfoque pragmático vs dogmático
                                                                                                                                                              
                                                                                                                                                               4. ### Para Peer Review
                                                                                                                                                              
                                                                                                                                                               5. 1. Examinar código en ramas específicas
                                                                                                                                                                  2. 2. Validar decisiones de seguridad
                                                                                                                                                                     3. 3. Sugerir mejoras en implementación
                                                                                                                                                                       
                                                                                                                                                                        4. ---
                                                                                                                                                                       
                                                                                                                                                                        5. ## ⚠️ Lo Que NO Verás Aquí
                                                                                                                                                                       
                                                                                                                                                                        6. - ❌ Microservicios por defecto
                                                                                                                                                                           - - ❌ Over-engineering sin propósito
                                                                                                                                                                             - - ❌ Dashboards infinitos sin contexto
                                                                                                                                                                               - - ❌ IA empleada por postureo
                                                                                                                                                                                 - - ❌ Procesos sin justificación
                                                                                                                                                                                   - - ❌ Documentación superficial
                                                                                                                                                                                    
                                                                                                                                                                                     - ---
                                                                                                                                                                                     
                                                                                                                                                                                     ## 🔗 Posicionamiento en NTT Data
                                                                                                                                                                                     
                                                                                                                                                                                     Este portfolio demuestra capacidad para:
                                                                                                                                                                                     
                                                                                                                                                                                     - ✅ Actuar como **ISE**: diseño y ejecución
                                                                                                                                                                                     - - ✅ Actuar como **ISX**: selección y justificación
                                                                                                                                                                                       - - ✅ Actuar como **ISA**: arquitectura integrada
                                                                                                                                                                                       
                                                                                                                                                                                       Habilidades clave para promoción a ISA:
                                                                                                                                                                                       1. Conectar negocio → riesgo → tecnología
                                                                                                                                                                                       2. 2. Documentar decisiones de forma profesional
                                                                                                                                                                                          3. 3. Justificar trade-offs
                                                                                                                                                                                             4. 4. Demostrar realismo vs dogmatismo
                                                                                                                                                                                             
                                                                                                                                                                                             ---
                                                                                                                                                                                             
                                                                                                                                                                                             ## 📅 Roadmap 2026
                                                                                                                                                                                             
                                                                                                                                                                                             - **Q1**: Completar Proyecto 1 (Hybrid DevSecOps Lab)
                                                                                                                                                                                             - - **Q2**: Implementar Proyecto 2 (CI/CD Pipeline)
                                                                                                                                                                                               - - **Q3**: Integrar Proyecto 3 (Observabilidad)
                                                                                                                                                                                                 - - **Q4**: Añadir Proyecto 4 (Automatización + IA)
                                                                                                                                                                                                  
                                                                                                                                                                                                   - ---
                                                                                                                                                                                                   
                                                                                                                                                                                                   ## 📞 Contacto & Feedback
                                                                                                                                                                                                   
                                                                                                                                                                                                   Para consultas o sugerencias sobre arquitectura, decisiones de diseño o mejoras:
                                                                                                                                                                                                   
                                                                                                                                                                                                   - 📧 Email: [tu email]
                                                                                                                                                                                                   - - 💼 LinkedIn: [tu perfil]
                                                                                                                                                                                                     - - 🐙 GitHub: @chunche95
                                                                                                                                                                                                      
                                                                                                                                                                                                       - ---
                                                                                                                                                                                                       
                                                                                                                                                                                                       **Última actualización**: Enero 2026
                                                                                                                                                                                                       **Versión**: 1.0
