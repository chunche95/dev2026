# Proyecto 4: Automatización Inteligente n8n + IA

## 📋 Resumen Ejecutivo

Automatizaciones con valor real + IA como capacidad auxiliar (no como producto). Demuestra eficiencia, control de costes y pensamiento arquitectónico pragmático.

## 🎯 Principios

1. **Automación = Valor**: No por "porque mola"
2. 2. **IA = Auxiliar**: Dónde aporta, dónde no, por qué
   3. 3. **Costes Controlados**: Token tracking explícito
      4. 4. **Documentación Clara**: Decisiones justificadas
        
         5. ## 🚀 Casos de Uso Reales
        
         6. ### 1. Monitorización de Infraestructura + Alertas
        
         7. ```
            ┌─────────────────────────────────────────┐
            │  Proyecto 3 (Alertas)                   │
            │                                         │
            │  AlertManager → Webhook                 │
            └────────────┬────────────────────────────┘
                         │
                         ▼
                   ┌──────────────┐
                   │   n8n Flow   │
                   ├──────────────┤
                   │ 1. Recibe alerta
                   │ 2. Enriquece contexto
                   │    (consulta Prom)
                   │ 3. Resumen con IA
                   │    (OpenAI/Claude)
                   │ 4. Ejecuta acción
                   │    (Slack, Mail, etc)
                   └──────────────┘
                         │
                         ├─→ Slack notification
                         ├─→ Email digest
                         └─→ PagerDuty event
            ```

            ### 2. Análisis de Logs Automático

            ```
            Loki logs → n8n Flow
                │
                ├─→ Parse logs (regex)
                ├─→ Detectar anomalías (pattern matching)
                ├─→ Si anomalía encontrada:
                │   └─→ IA: "¿Qué significa esto?"
                │       └─→ Resumen de causa probable
                │       └─→ Acciones recomendadas
                │       └─→ Notificar team
                └─→ Update Grafana annotation
            ```

            ### 3. Generación Automática de Reportes

            ```
            Daily 06:00 UTC
                │
                ├─→ Query Prometheus (24h)
                ├─→ Query Loki (errors)
                ├─→ Calcular métricas DORA
                ├─→ IA: Generar narrative
                │   "El deployment frequency bajó 20% porque..."
                └─→ Email HTML report
            ```

            ## 📚 Stack

            | Componente | Tool | Razón |
            |---|---|---|
            | **Workflow** | n8n Open Source | Self-hosted, flexible |
            | **IA** | OpenAI / Claude / Local | Según necesidad |
            | **Integración** | Webhooks / APIs | Estándar |
            | **Almacenamiento** | PostgreSQL | Data persistence |

            ## 📂 Estructura

            ```
            04-n8n-automation/
            ├── README.md
            ├── workflows/
            │   ├── 01-alert-enrichment.json
            │   │   (AlertManager → Slack + Email)
            │   ├── 02-log-analysis.json
            │   │   (Loki → Anomaly detection → IA)
            │   ├── 03-daily-report.json
            │   │   (Prom + Loki → Report)
            │   ├── 04-deployment-workflow.json
            │   │   (Trigger on deploy)
            │   └── 05-cost-tracking.json
            │       (IA para analizar costes)
            │
            ├── ai-integration/
            │   ├── prompts.md
            │   │   ├── alert-enrichment-prompt.txt
            │   │   ├── log-analysis-prompt.txt
            │   │   ├── report-generation-prompt.txt
            │   │   └── cost-analysis-prompt.txt
            │   │
            │   └── token-tracking.md
            │       - Uso diario de tokens
            │       - Costes estimados
            │       - Mejoras propuestas
            │
            ├── integrations/
            │   ├── prometheus.md
            │   ├── loki.md
            │   ├── alertmanager.md
            │   ├── slack.md
            │   └── github.md
            │
            └── docker-compose.yml
                (n8n self-hosted)
            ```

            ## 🧠 Uso de IA - Documentación Explícita

            ### DÓNDE SÍ usamos IA

            1. **Resúmenes**: Procesar 1000+ líneas de logs → narrative coherente
            2. 2. **Clasificación**: Error type → causa probable → acciones
               3. 3. **Generación**: Reportes HTML desde datos brutos
                  4. 4. **Análisis**: Patrones en costes/performance
                    
                     5. ### DÓNDE NO usamos IA
                    
                     6. ❌ Decisiones críticas (despliegues, rollbacks)
                     7. ❌ Cambios de configuración automáticos
                     8. ❌ Acceso a datos sensibles
                     9. ❌ Cualquier cosa que requiera 100% confiabilidad
                    
                     10. ### Criterio de Decisión
                    
                     11. ```
                         Problem
                             │
                             ├─ "¿Es determinístico?"
                             │   YES → Lógica n8n pura
                             │    NO → ¿Necesita juicio humano?
                             │        YES → Manual (notify team)
                             │         NO → IA puede ayudar
                             │
                             └─ ¿Costo token aceptable?
                                YES → Implementar
                                 NO → Alternative approach
                         ```

                         ## 💰 Control de Costes (Crítico)

                         ### Token Tracking Explícito

                         ```yaml
                         # config.yml
                         openai_api_key: ${OPENAI_API_KEY}
                         rate_limit:
                           alerts_per_day: 50      # Max 50 alerts processed
                           tokens_per_alert: 100   # Máx 100 tokens por alerta
                           cost_per_1k_tokens: 0.002
                           daily_budget: $1.00

                         logging:
                           track_tokens: true      # Log cada llamada
                           alert_on_budget: true   # Alerta si > 80% budget
                         ```

                         ### Monitoreo

                         ```
                         Daily (midnight):
                           - Total tokens used: XXX
                           - Total cost: $X.XX
                           - Budget remaining: $Y.YY
                           - Status: ✅ OK / ⚠️ WARNING / 🔴 OVER
                         ```

                         ## 🚀 Flujo Simplificado

                         ### Ejemplo: Alert Enrichment

                         ```bash
                         # AlertManager dispara alerta
                         POST http://n8n.local:5678/webhook/alerts

                         # n8n recibe:
                         {
                           "alerts": [
                             {
                               "name": "HighErrorRate",
                               "value": "95%",
                               "duration": "5m"
                             }
                           ]
                         }

                         # n8n ejecuta:
                         1. Query Prometheus ("¿más contexto de esta métrica?")
                         2. Query Loki ("¿qué logs asociados?")
                         3. IA prompt:
                            "Dado que error rate es 95% y estos son los logs...
                             ¿Cuál es la causa probable y qué debería hacer?"
                         4. Response:
                            "Probable causa: Database connection pool exhausted.
                             Acciones: 1. Scale DB, 2. Review connection settings"
                         5. Format + Send Slack:
                            "🚨 HIGH ERROR RATE (95%)
                             📊 Context: 2300 requests/sec, ~2100 errors
                             🔍 Probable: DB pool exhausted
                             ✅ Actions: See thread"
                         ```

                         ## 🧪 Validación

                         Criterios de aceptación:
                         - ✅ n8n instalado y funcional
                         - - ✅ Webhooks funcionando
                           - - ✅ Integraciones Prom/Loki OK
                             - - ✅ Flujos básicos ejecutando
                               - - ✅ Token tracking visible
                                 - - ✅ Cero decisiones críticas en IA
                                   - - ✅ Documentación explícita de IA usage
                                    
                                     - ## 🔄 Integración
                                    
                                     - - **Proyecto 1**: n8n corre aquí (k3s)
                                       - - **Proyecto 2**: Notificaciones de pipeline
                                         - - **Proyecto 3**: Consume alertas de Prometheus/Loki
                                          
                                           - ## ⚠️ Lo Que NO Hacemos
                                          
                                           - ❌ Agentes IA autónomos
                                           - ❌ Automatización sin human oversight
                                           - ❌ IA para decisiones críticas
                                           - ❌ Consumo descontrolado de tokens
                                           - ❌ IA sin justificación documentada
                                          
                                           - ## 🎓 Lecciones para Arquitectos
                                          
                                           - Este proyecto demuestra:
                                           - 1. **Pragmatismo**: IA donde aporta, no donde "mola"
                                             2. 2. **Conciencia de Costes**: Tracking explícito
                                                3. 3. **Transparencia**: Documentar dónde sí/no se usa IA
                                                   4. 4. **Integración Real**: No es un proyecto aislado
                                                     
                                                      5. Es lo que diferencia a un **ISA** (Arquitecto) de un **ISE** (Ingeniero).
                                                     
                                                      6. ## 📚 Referencias
                                                     
                                                      7. - [n8n Documentation](https://docs.n8n.io/)
                                                         - - [Prompt Engineering Best Practices](https://platform.openai.com/docs/guides/prompt-engineering)
                                                           - - [Token Counter](https://github.com/openai/openai-cookbook/blob/main/examples/How_to_count_tokens_with_tiktoken.ipynb)
