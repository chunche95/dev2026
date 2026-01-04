# Proyecto 3: Observabilidad Foundation

## 📋 Resumen Ejecutivo

Stack de observabilidad integrado (Prometheus + Loki + Grafana) orientado a **decisiones**, no dashboards. Capacidad transversal, no especialidad de operadores.

## 🎯 Principios

1. **¿QUÉ se mide?** - Métricas con propósito
2. 2. **¿POR QUÉ?** - Contexto empresarial
   3. 3. **¿QUÉ decisión permite tomar?** - Actionable insights
     
      4. ## 📊 Arquitectura
     
      5. ```
         Proyecto 1 (k3s cluster)
             │
             ├─→ Prometheus (Scraping de métricas)
             │   └─→ ServiceMonitor CRDs
             │   └─→ PrometheusRules (alertas)
             │
             ├─→ Loki (Log aggregation)
             │   └─→ Ingester nodes
             │   └─→ Query frontend
             │
             ├─→ Grafana (Visualización)
             │   └─→ Dashboards por función
             │   └─→ Alertas
             │
             └─→ AlertManager (Gestión de alertas)
                 └─→ Routes a Slack, PagerDuty, etc.

         Proyecto 2 (CI/CD Pipeline)
             └─→ Envía logs a Loki
             └─→ Publica métricas a Prometheus
         ```

         ## 🔍 Métricas Clave (No infinitos dashboards)

         ### Por Aplicación
         - Latency (p50, p95, p99)
         - - Error rate (%)
           - - Request volume
             - - CPU/Memory usage
              
               - ### Por Infraestructura
               - - Node health
                 - - Pod restart count
                   - - Storage I/O
                     - - Network throughput
                      
                       - ### Por Negocio
                       - - Deployment frequency
                         - - Lead time (commit → production)
                           - - MTTR (Mean Time To Recovery)
                             - - Change failure rate
                              
                               - ## 📚 Stack
                              
                               - | Componente | Versión | Razón |
                               - |---|---|---|
                               - | **Prometheus** | 2.x | Time-series DB + scraping |
                               - | **Loki** | 2.x | Log aggregation sin indexing |
                               - | **Grafana** | 9.x+ | Visualización unificada |
                               - | **Alert Manager** | 0.x | Deduplicación + routing |
                              
                               - ## 📂 Estructura
                              
                               - ```
                                 03-observability-foundation/
                                 ├── README.md
                                 ├── prometheus/
                                 │   ├── prometheus-deployment.yaml
                                 │   ├── prometheus-service.yaml
                                 │   ├── prometheus-config.yaml
                                 │   ├── service-monitors/ (ServiceMonitor CRDs)
                                 │   └── alerting-rules.yaml
                                 ├── loki/
                                 │   ├── loki-deployment.yaml
                                 │   ├── loki-service.yaml
                                 │   ├── loki-config.yaml
                                 │   └── promtail-daemonset.yaml (log shipping)
                                 ├── grafana/
                                 │   ├── grafana-deployment.yaml
                                 │   ├── grafana-service.yaml
                                 │   ├── datasources/ (Prometheus + Loki)
                                 │   └── dashboards/
                                 │       ├── application-health.json
                                 │       ├── infrastructure-metrics.json
                                 │       ├── deployment-pipeline.json
                                 │       └── business-metrics.json
                                 ├── alertmanager/
                                 │   ├── alertmanager-deployment.yaml
                                 │   ├── alertmanager-config.yaml
                                 │   └── notification-routes.yaml
                                 └── helm/
                                     ├── Chart.yaml
                                     └── values.yaml
                                 ```

                                 ## 🚨 Alertas Configuradas

                                 ### CRÍTICAS (Páginas en OOH)
                                 - Aplicación caída (0 requests > 5 min)
                                 - - Error rate > 50% (5 min)
                                   - - Node down
                                     - - Storage casi lleno (> 90%)
                                      
                                       - ### MAYORES (Ticket automático)
                                       - - Latency p95 > SLA (5 min)
                                         - - CPU > 80% (10 min)
                                           - - Pod restart loops
                                            
                                             - ### MENORES (Log)
                                             - - Latency p95 > nominal (5 min)
                                               - - Memory growing (trending)
                                                
                                                 - ## 🎓 Cómo NO Hacer Observabilidad
                                                
                                                 - ❌ Créer dashboards sin contexto
                                                 - ❌ Meter 100 métricas sin propósito
                                                 - ❌ Configurar alertas para TODO
                                                 - ❌ Nunca revisar alertas viejas
                                                
                                                 - ## ✅ Cómo Hacerlo Bien
                                                
                                                 - ✅ Empezar con 5-10 métricas clave
                                                 - ✅ Evolucionar según preguntas reales
                                                 - ✅ Alertas = decisiones accionables
                                                 - ✅ Revisar y refinar cada mes
                                                
                                                 - ## 🔄 Integración
                                                
                                                 - - **Proyecto 1**: Está aquí (k3s host)
                                                   - - **Proyecto 2**: CI/CD publica métricas
                                                     - - **Proyecto 4**: n8n consume alertas para automatización
                                                      
                                                       - ## 📚 Referencias
                                                      
                                                       - - [Prometheus Operator](https://prometheus-operator.dev/)
                                                         - - [Grafana Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
                                                           - - [Observability Engineering Book](https://www.oreilly.com/library/view/observability-engineering/9781492076438/)
