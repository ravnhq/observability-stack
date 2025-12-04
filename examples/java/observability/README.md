# LGTM Observability Stack

Self-contained deployment of the Grafana LGTM (Loki, Grafana, Tempo, Mimir) observability stack with Alloy as the telemetry collector.

## Overview

This directory contains everything needed to run a complete observability backend:

- **Grafana** - Visualization and dashboarding
- **Mimir** - Metrics storage (Prometheus-compatible)
- **Loki** - Log aggregation
- **Tempo** - Distributed tracing
- **Alloy** - Telemetry collector and router

## Quick Start

### Standalone LGTM Stack

Deploy the observability stack independently:

```bash
cd observability
docker-compose up -d
```

### Access Points

Once running, access the services:

- **Grafana**: http://localhost:3030
  - Default credentials: `admin` / `admin` (change via `GRAFANA_ADMIN_PASSWORD` in `.env`)
  - Pre-configured datasources for Mimir, Loki, and Tempo

- **Alloy UI**: http://localhost:12345
  - View telemetry pipeline configuration
  - Monitor scrape targets and OTLP receivers

- **OTLP Endpoints** (for applications to send telemetry):
  - HTTP: http://localhost:4318
  - gRPC: http://localhost:4317

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
cp .env.example .env
```

Key configuration options:

#### Service Ports
```bash
GRAFANA_PORT=3030
ALLOY_OTLP_HTTP_PORT=4318
ALLOY_OTLP_GRPC_PORT=4317
MIMIR_PORT=9009
LOKI_PORT=3100
TEMPO_PORT=3200
```

#### External Scrape Targets

Configure Alloy to scrape metrics from applications running outside the LGTM stack:

```bash
# PostgreSQL exporter scraping
SCRAPE_POSTGRES_TARGET=host.docker.internal:9187  # or remote-host:9187
SCRAPE_POSTGRES_JOB=postgresql
SCRAPE_POSTGRES_METRICS_PATH=/metrics

# Application metrics scraping
SCRAPE_APP_TARGET=host.docker.internal:8081  # or remote-host:8081
SCRAPE_APP_JOB=userdemo-agent-micrometer
SCRAPE_APP_METRICS_PATH=/actuator/prometheus
```

#### Data Retention

```bash
LOKI_RETENTION_HOURS=168     # 7 days
TEMPO_RETENTION_HOURS=336    # 14 days
MIMIR_RETENTION_HOURS=8760   # 365 days
```

#### Storage Backend

Local filesystem (default):
```bash
STORAGE_TYPE=filesystem
STORAGE_MODE=local
```

Amazon S3:
```bash
STORAGE_TYPE=s3
STORAGE_MODE=s3
AWS_REGION=us-west-2
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
S3_BUCKET_METRICS=my-mimir-bucket
S3_BUCKET_LOGS=my-loki-bucket
S3_BUCKET_TRACES=my-tempo-bucket
```

Google Cloud Storage:
```bash
STORAGE_TYPE=gcs
STORAGE_MODE=gcs
GCS_BUCKET_METRICS=my-mimir-bucket
GCS_BUCKET_LOGS=my-loki-bucket
GCS_BUCKET_TRACES=my-tempo-bucket
```

## Deployment Scenarios

### Scenario 1: Co-located with Application (Same Host)

Both LGTM stack and application running on the same machine:

1. Start LGTM stack:
   ```bash
   cd observability
   docker-compose up -d
   ```

2. Start application (in separate terminal):
   ```bash
   cd ..
   docker-compose up -d
   ```

3. Default configuration uses `host.docker.internal` for scrape targets, which works out of the box.

### Scenario 2: Distributed Deployment (Different Hosts)

LGTM stack on dedicated host, applications on separate hosts:

**On LGTM Host (e.g., 10.0.1.100):**

1. Update `observability/.env`:
   ```bash
   SCRAPE_POSTGRES_ENABLED=true
   SCRAPE_POSTGRES_TARGET=10.0.1.101:9187  # Application host
   SCRAPE_APP_TARGET=10.0.1.101:8081       # Application host
   ```

2. Start LGTM stack:
   ```bash
   cd observability
   docker-compose up -d
   ```

**On Application Host (e.g., 10.0.1.101):**

1. Configure app to send telemetry to LGTM host:
   ```bash
   # In application .env
   OTEL_EXPORTER_OTLP_ENDPOINT=http://10.0.1.100:4318
   ```

2. Ensure ports are accessible:
   - Application must expose: 8081 (app metrics), 9187 (postgres exporter)
   - LGTM stack must expose: 4318 (OTLP HTTP), 4317 (OTLP gRPC)

### Scenario 3: LGTM-Only (No External Scraping)

Run LGTM stack without scraping external targets:

1. Start stack:
   ```bash
   docker-compose up -d
   ```

The stack will receive telemetry via OTLP but won't actively scrape external endpoints.

## Data Flow

### Metrics
- Applications expose Prometheus `/metrics` endpoints
- Alloy scrapes these endpoints periodically
- Applications send OTLP metrics to Alloy
- Alloy forwards metrics to Mimir
- Tempo's metrics generator sends RED metrics to Mimir
- Grafana queries Mimir for visualization

### Logs
- Applications send logs via OTLP to Alloy
- Alloy forwards logs to Loki
- Grafana queries Loki for log viewing
- Logs are correlated with traces via trace_id

### Traces
- Applications send OTLP traces to Alloy
- Alloy forwards traces to Tempo
- Tempo stores traces and generates RED metrics
- Grafana queries Tempo for trace visualization
- Traces link to logs and metrics

## Monitoring & Troubleshooting

### Check Service Health

```bash
docker-compose ps
```

All services should show "Up" status.

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f alloy
docker-compose logs -f grafana
```

### Verify Alloy Configuration

1. Open Alloy UI: http://localhost:12345
2. Check "Targets" to see scrape jobs
3. Verify OTLP receivers are listening
4. Monitor pipeline metrics

### Check Datasources in Grafana

1. Open Grafana: http://localhost:3030
2. Navigate to: Configuration → Data Sources
3. Test each datasource (Mimir, Loki, Tempo)
4. All should show green "Success" status

### Common Issues

**Issue: Alloy can't scrape external targets**
- Solution: Verify `host.docker.internal` resolves correctly
- On Linux: Ensure `extra_hosts` is configured in docker-compose
- For remote targets: Use actual hostname/IP instead

**Issue: Applications can't send to Alloy**
- Solution: Check OTLP endpoint is accessible
- Verify firewall rules allow connections to port 4318/4317
- Test: `curl http://localhost:4318/v1/traces` should return 405

**Issue: Grafana datasources failing**
- Solution: Check internal network connectivity
- Verify services are running: `docker-compose ps`
- Check service logs for errors

## Performance Tuning

### Ingestion Rate Limits

Adjust in `.env`:

```bash
# Metrics
MIMIR_INGESTION_RATE=50000          # samples/sec
MIMIR_INGESTION_BURST=100000

# Logs
LOKI_INGESTION_RATE_MB=4            # MB/sec
LOKI_INGESTION_BURST_MB=6

# Traces
TEMPO_INGESTION_RATE_MB=100         # MB/sec
TEMPO_INGESTION_BURST_MB=200
```

### Scrape Intervals

Edit `alloy.alloy`:

```alloy
scrape_interval = "15s"  # Default
scrape_timeout  = "10s"
```

## Production Considerations

### High Availability

For production HA setup:

1. Update replication factors:
   ```bash
   MIMIR_REPLICATION_FACTOR=3
   LOKI_REPLICATION_FACTOR=3
   TEMPO_REPLICATION_FACTOR=3
   ```

2. Use distributed KV store:
   ```bash
   KVSTORE_TYPE=etcd  # or consul
   ```

3. Deploy multiple instances behind load balancer

### Security

1. Change default credentials:
   ```bash
   GRAFANA_ADMIN_PASSWORD=strong_password_here
   ```

2. Enable TLS:
   ```bash
   TLS_ENABLED=true
   ```

3. Use cloud storage with encryption:
   ```bash
   S3_SSE_TYPE=SSE-KMS
   S3_KMS_KEY_ID=your-kms-key-id
   ```

4. Restrict network access with firewall rules

### Backup & Disaster Recovery

- **Filesystem mode**: Backup `./data/` directories
- **S3/GCS mode**: Use cloud-native backup/versioning
- **Grafana dashboards**: Export and version control
- **Configuration**: Keep `.env` and config files in git

## Resource Requirements

Minimum (development):
- CPU: 4 cores
- RAM: 8 GB
- Disk: 20 GB (with retention cleanup)

Recommended (production):
- CPU: 8-16 cores
- RAM: 32-64 GB
- Disk: 100+ GB or cloud storage

## Upgrading

To upgrade services to newer versions:

1. Stop stack:
   ```bash
   docker-compose down
   ```

2. Pull latest images:
   ```bash
   docker-compose pull
   ```

3. Restart stack:
   ```bash
   docker-compose up -d
   ```

4. Verify all services healthy

## Support & Documentation

- [Grafana Alloy Docs](https://grafana.com/docs/alloy/)
- [Grafana Mimir Docs](https://grafana.com/docs/mimir/)
- [Grafana Loki Docs](https://grafana.com/docs/loki/)
- [Grafana Tempo Docs](https://grafana.com/docs/tempo/)
- [Grafana Dashboard Docs](https://grafana.com/docs/grafana/)
