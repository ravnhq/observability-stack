# LGTM Observability Stack for ExpressJS

This setup integrates the **LGTM Stack** (Loki, Grafana, Tempo, Mimir/Prometheus) with your ExpressJS application using OpenTelemetry.

## 🏗️ Architecture

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────┐
│   ExpressJS App    │────▶│  OpenTelemetry       │────▶│   Tempo     │ (Traces)
│                 │     │  Collector           │     └─────────────┘
│  - Traces       │     │                      │     ┌─────────────┐
│  - Metrics      │     │  - Receives OTLP     │────▶│   Loki      │ (Logs)
│  - Logs         │     │  - Routes telemetry  │     └─────────────┘
└─────────────────┘     │  - Transforms data   │     ┌─────────────┐
                        └──────────────────────┘────▶│ Prometheus  │ (Metrics)
                                                     └─────────────┘
                                                           │
                                                           ▼
                                                     ┌─────────────┐
                                                     │   Grafana   │ (Visualization)
                                                     └─────────────┘
```

## 🚀 Quick Start

### 1. Start the entire stack with Docker Compose

```bash
docker-compose up -d
```

### 2. Or start just the observability stack (run app locally)

```bash
# Start only observability services
docker-compose up -d grafana tempo loki postgres mimir alloy

# Run ExpressJS app locally
npm run start
```

### 3. Access the services

| Service     | URL                          | Credentials       |
|-------------|------------------------------|-------------------|
| ExpressJS App  | http://localhost:3000        | -                 |
| Grafana     | http://localhost:3001        | admin / admin     |
| Prometheus  | http://localhost:9090        | -                 |
| Loki        | http://localhost:3100        | -                 |
| Tempo       | http://localhost:3200        | -                 |

## 📊 What's Included

### Traces (Tempo)
- Automatic HTTP request tracing
- Database query tracing (Prisma)
- Custom spans support
- Distributed tracing across services

### Metrics (Prometheus)
- HTTP request rate
- Request latency histograms (P50, P95, P99)
- Error rates by endpoint
- Custom metrics support

### Logs (Loki)
- Structured JSON logging with Pino
- Automatic request/response logging
- Log correlation with trace IDs
- Log levels and filtering

### Dashboards (Grafana)
- Pre-configured ExpressJS Overview dashboard
- Request rate and latency graphs
- Error tracking
- Log viewer with trace correlation
- Trace explorer

## 🔧 Configuration

### Environment Variables

| Variable            | Description                      | Default                    |
|---------------------|----------------------------------|----------------------------|
| `OTEL_COLLECTOR_URL`| OpenTelemetry Collector endpoint | `http://localhost:4318`    |
| `OTEL_SERVICE_NAME` | Service name for telemetry       | `express-app`               |
| `LOG_LEVEL`         | Logging level                    | `info`                     |
| `NODE_ENV`          | Environment                      | `development`              |

### Adding Custom Traces

```typescript
import { trace } from '@opentelemetry/api';

const tracer = trace.getTracer('my-service');

async function myFunction() {
  const span = tracer.startSpan('my-operation');
  try {
    // Your code here
    span.setAttribute('custom.attribute', 'value');
  } finally {
    span.end();
  }
}
```

### Adding Custom Metrics

```typescript
import { metrics } from '@opentelemetry/api';

const meter = metrics.getMeter('my-service');
const counter = meter.createCounter('my_custom_counter', {
  description: 'Counts something',
});

counter.add(1, { label: 'value' });
```

### Adding Custom Logs

```typescript
import { Logger } from '@nestjs/common';

@Injectable()
export class MyService {
  private readonly logger = new Logger(MyService.name);

  myMethod() {
    this.logger.log('This is an info log');
    this.logger.warn('This is a warning');
    this.logger.error('This is an error', error.stack);
  }
}
```

## 📁 File Structure

```
observability/
├── otel-collector-config.yaml  # OpenTelemetry Collector configuration
├── tempo.yaml                  # Tempo (tracing) configuration
├── loki.yaml                   # Loki (logging) configuration
├── prometheus.yaml             # Prometheus (metrics) configuration
└── grafana/
    ├── provisioning/
    │   ├── datasources/
    │   │   └── datasources.yaml  # Grafana datasource configuration
    │   └── dashboards/
    │       └── dashboards.yaml   # Dashboard provisioning
    └── dashboards/
        └── nestjs-overview.json  # Pre-built dashboard
```

## 🔍 Exploring Data in Grafana

### View Traces
1. Go to Grafana → Explore
2. Select "Tempo" datasource
3. Search by service name: `express-app`

### View Logs
1. Go to Grafana → Explore
2. Select "Loki" datasource
3. Query: `{service_name="express-app"}`

### View Metrics
1. Go to Grafana → Explore
2. Select "Prometheus" datasource
3. Query: `http_server_request_duration_seconds_count{service_name="express-app"}`

### Correlate Logs with Traces
- Click on a trace ID in logs to jump to the trace
- Click on a trace to see related logs

## 🛠️ Troubleshooting

### No data in Grafana?
1. Check if all containers are running: `docker-compose ps`
2. Check OTEL collector logs: `docker-compose logs otel-collector`
3. Verify the app is sending data: `curl http://localhost:4318/v1/traces`

### Traces not appearing?
1. Ensure `OTEL_COLLECTOR_URL` is correct
2. Check Tempo logs: `docker-compose logs tempo`

### Logs not appearing?
1. Check Loki logs: `docker-compose logs loki`
2. Verify log format in OTEL collector config

## 📚 Resources

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Grafana LGTM Stack](https://grafana.com/oss/lgtm-stack/)
- [ExpressJS Documentation](https://docs.nestjs.com/)
