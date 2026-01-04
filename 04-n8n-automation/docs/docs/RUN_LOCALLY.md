# Running n8n Locally

Quick start guide for running the n8n automation platform with PostgreSQL on your development machine.

## Prerequisites

- Docker and Docker Compose installed
- - Available ports: 5678 (n8n), 5432 (PostgreSQL)
  - - Unix-based system (Linux/macOS) or Windows with WSL2
   
    - ## Setup Instructions
   
    - ### 1. Configure Environment Variables
   
    - Create a `.env` file from the template:
   
    - ```bash
      cp .env.example .env
      ```

      Edit `.env` with secure values:

      ```env
      POSTGRES_PASSWORD=your_secure_postgres_password
      N8N_PASSWORD=your_secure_n8n_password
      TIMEZONE=UTC
      ```

      **Security Note:** Never commit your `.env` file. It's already in `.gitignore`.

      ### 2. Start Services

      Launch n8n and PostgreSQL:

      ```bash
      docker-compose up -d
      ```

      Verify containers are running:

      ```bash
      docker-compose ps
      ```

      Expected output:
      - `n8n-postgres`: Running
      - - `n8n-app`: Running
       
        - ### 3. Access n8n
       
        - Open your browser to: **http://localhost:5678**
       
        - Login with:
        - - Username: admin
          - - Password: (from your .env file)
           
            - ## Workflow Examples
           
            - ### Importing the Alert Enrichment Workflow
           
            - 1. Go to **Workflows** → **Import from file**
              2. 2. Select `workflows/sample-alert-enrichment.json`
                 3. 3. Review the workflow nodes (webhook, Prometheus query, conditional logic)
                    4. 4. Configure the external webhook endpoint in environment variables
                      
                       5. ### Testing the Workflow
                      
                       6. Send a test alert to the webhook:
                      
                       7. ```bash
                          curl -X POST http://localhost:5678/webhook/alerts \
                            -H "Content-Type: application/json" \
                            -d '{
                              "alerts": [{
                                "status": "firing",
                                "labels": {"alertname": "HighCPU", "job": "prometheus"}
                              }]
                            }'
                          ```

                          ## Common Tasks

                          ### View Logs

                          ```bash
                          docker-compose logs -f n8n
                          docker-compose logs -f postgres
                          ```

                          ### Database Access

                          Connect to PostgreSQL directly:

                          ```bash
                          docker-compose exec postgres psql -U n8n -d n8n
                          ```

                          ### Stop Services

                          ```bash
                          docker-compose down
                          ```

                          To also remove data volumes:

                          ```bash
                          docker-compose down -v
                          ```

                          ## Troubleshooting

                          ### Port Already in Use

                          If port 5678 is already used:

                          ```bash
                          # Find process using port
                          lsof -i :5678

                          # Change port in docker-compose.yml: 127.0.0.1:6678:5678
                          ```

                          ### Database Connection Issues

                          Ensure Postgres healthcheck passes:

                          ```bash
                          docker-compose logs postgres
                          docker-compose ps  # Check postgres health status
                          ```

                          ### n8n Won't Start

                          Check logs and wait for Postgres to be ready:

                          ```bash
                          docker-compose logs n8n
                          docker-compose restart n8n
                          ```

                          ## Architecture Notes

                          - **n8n**: Workflow automation engine (accessible on http://127.0.0.1:5678)
                          - - **PostgreSQL**: Persistent storage for workflows, credentials, and execution history
                            - - **Security**: Services bound to localhost only, auth enabled by default
                              - - **Restart Policy**: Both services auto-restart on failure (unless-stopped)
                               
                                - ## Next Steps
                               
                                - 1. Import the sample workflow from `workflows/sample-alert-enrichment.json`
                                  2. 2. Configure external webhook endpoints
                                     3. 3. Create custom workflows for your automation needs
                                        4. 4. Refer to n8n documentation: https://docs.n8n.io/
                                          
                                           5. ## Support
                                          
                                           6. For issues with n8n, see: https://docs.n8n.io/
                                           7. For Docker issues: https://docs.docker.com/
                                           8. 
