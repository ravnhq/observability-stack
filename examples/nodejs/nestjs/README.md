# Adding OpenTelemetry Observability to NestJS Applications

How to add **production-ready observability** to NestJS applications using OpenTelemetry, Prometheus, and the Grafana LGTM stack.

## Table of Contents
- [How to Setup the LGTM Stack](#how-to-setup-the-lgtm-stack)

## How to Setup the LGTM Stack

The LGTM observability stack (Loki, Grafana, Tempo, Mimir) can be installed with a single command using the provided installation script. The script automatically downloads all necessary configuration files and sets up the complete observability infrastructure.

### Prerequisites

The installation script validates the following dependencies automatically:
- **Docker**: Container runtime
- **Docker Compose**: Service orchestration
- **curl**: For downloading files

If any dependency is missing, the script will provide installation instructions.

### Installation Scenarios

#### Fresh Installation (Default)

Install the stack from the master branch to a new `./observability/` directory:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/master/install.sh)
```

**What this does:**
- Downloads essential files to `./observability/` directory
- Creates `.env` file from template
- Generates a secure Grafana admin password automatically

**Startup time:** Initial startup typically takes 2-3 minutes as Docker builds images and initializes services.

#### Branch-Specific Installation

Install from a specific Git branch (e.g., to test new features or use a development version):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/nestjs-example/install.sh) --branch nestjs-example
```

**Note:** When using a different branch, ensure the URL path matches the branch name in both the download URL and the `--branch` parameter.

### Post-Installation Configuration

After installation, review and modify `./observability/.env` to adapt the stack to your deployment infrastructure:

#### Storage Configuration

```bash
# Storage backend type
STORAGE_TYPE=filesystem  # Options: filesystem, s3, gcs
```

- **filesystem**: Data stored locally (default, good for development)
- **s3**: AWS S3 buckets (recommended for production)
- **gcs**: Google Cloud Storage (alternative for GCP deployments)

#### Cloud Storage Credentials (if using S3)

```bash
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1

# S3 bucket names
LOKI_S3_BUCKET=loki-logs
TEMPO_S3_BUCKET=tempo-traces
MIMIR_S3_BUCKET=mimir-metrics
```

#### Cloud Storage Credentials (if using GCS)

```bash
GCS_BUCKET_NAME=your-bucket-name
GCS_SERVICE_ACCOUNT_KEY=/path/to/service-account-key.json
```

#### Port Configuration

Adjust ports if defaults conflict with existing services:

```bash
GRAFANA_PORT=3030        # Default Grafana UI
ALLOY_OTLP_GRPC_PORT=4317  # OTLP gRPC endpoint
ALLOY_OTLP_HTTP_PORT=4318  # OTLP HTTP endpoint
ALLOY_UI_PORT=12345        # Alloy configuration UI
```

#### Data Retention Periods

Configure how long telemetry data is stored:

```bash
LOKI_RETENTION_PERIOD=168h    # 7 days (logs)
TEMPO_RETENTION_PERIOD=336h   # 14 days (traces)
MIMIR_RETENTION_PERIOD=8760h  # 365 days (metrics)
```

#### Scrape Targets (for distributed deployments)

Configure external endpoints for Prometheus scraping:

```bash
# Application metrics endpoint
SCRAPE_APP_TARGET=host.docker.internal:8080
SCRAPE_APP_METRICS_PATH=/actuator/prometheus

# PostgreSQL exporter metrics
SCRAPE_POSTGRES_TARGET=host.docker.internal:9187
SCRAPE_POSTGRES_METRICS_PATH=/metrics

# Node exporter metrics
SCRAPE_NODE_EXPORTER_TARGET=host.docker.internal:9100
SCRAPE_NODE_EXPORTER_METRICS_PATH=/metrics
```

For distributed deployments where applications run on different hosts, replace `host.docker.internal` with the actual hostname or IP address.

### Access Points

After the stack is running, access these services:

| Service | URL | Credentials | Purpose |
|---------|-----|-------------|---------|
| **Grafana** | http://localhost:3030 | admin / [generated-password]* | Visualization dashboards |
| **Alloy UI** | http://localhost:12345 | None | Telemetry pipeline status |
| **OTLP gRPC** | localhost:4317 | None | Application trace/metric submission |
| **OTLP HTTP** | localhost:4318 | None | Application trace/metric submission |

**\*Note:** The Grafana password is displayed in the installation output and saved in `./observability/.env`

