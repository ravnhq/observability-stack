# Express.js OpenTelemetry Integration

Simple steps to add complete observability (metrics, traces, logs, profiling) to your Express.js application.

## 🚀 Quick Setup (5 minutes)

### 1. Install Dependencies

```bash
npm install @opentelemetry/sdk-node \
            @opentelemetry/auto-instrumentations-node \
            @opentelemetry/exporter-trace-otlp-http \
            @opentelemetry/exporter-metrics-otlp-http \
            @opentelemetry/sdk-metrics \
            @opentelemetry/resources \
            @opentelemetry/instrumentation-pg \
            @opentelemetry/instrumentation-winston \
            @prisma/instrumentation \
            winston \
            winston-loki \
            @pyroscope/nodejs \
            dotenv
```

### 2. Create `src/config/telemetry.ts`

```typescript
import dotenv from 'dotenv';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { defaultResource, resourceFromAttributes } from '@opentelemetry/resources';
import { PrismaInstrumentation } from '@prisma/instrumentation';
import { PgInstrumentation } from '@opentelemetry/instrumentation-pg';
import { WinstonInstrumentation } from '@opentelemetry/instrumentation-winston';

// Pyroscope profiling
import Pyroscope from '@pyroscope/nodejs';

// Load environment variables
dotenv.config();

const TELEMETRY_ENABLED = process.env.TELEMETRY_ENABLED !== 'false';
const SERVICE_NAME = process.env.SERVICE_NAME || 'my-express-app';
const SERVICE_VERSION = process.env.SERVICE_VERSION || '1.0.0';
const OTLP_ENDPOINT = process.env.OTLP_ENDPOINT || 'http://localhost:4318';
const PYROSCOPE_ENDPOINT = process.env.PYROSCOPE_ENDPOINT || 'http://localhost:4040';
const METRIC_EXPORT_INTERVAL = Number(process.env.METRIC_EXPORT_INTERVAL) || 5000;

let sdk: NodeSDK | null = null;

export async function startTelemetry() {
  if (!TELEMETRY_ENABLED) {
    console.log('⚠️ Telemetry disabled');
    return;
  }

  // Initialize Pyroscope profiling
  if (process.env.PYROSCOPE_ENABLED !== 'false') {
    Pyroscope.init({
      serverAddress: PYROSCOPE_ENDPOINT,
      appName: SERVICE_NAME,
      tags: {
        version: SERVICE_VERSION,
        environment: process.env.NODE_ENV || 'development',
      }
    });
    console.log('🔥 Pyroscope profiling enabled');
  }

  const resource = defaultResource().merge(
    resourceFromAttributes({
      'service.name': SERVICE_NAME,
      'service.version': SERVICE_VERSION,
      'deployment.environment': process.env.NODE_ENV || 'development',
    })
  );

  const traceExporter = new OTLPTraceExporter({
    url: `${OTLP_ENDPOINT}/v1/traces`,
  });

  const metricExporter = new OTLPMetricExporter({
    url: `${OTLP_ENDPOINT}/v1/metrics`,
  });

  const metricReader = new PeriodicExportingMetricReader({
    exporter: metricExporter,
    exportIntervalMillis: METRIC_EXPORT_INTERVAL,
  });

  sdk = new NodeSDK({
    resource,
    traceExporter,
    metricReader,
    instrumentations: [
      // Database instrumentation
      new PrismaInstrumentation(),
      new PgInstrumentation({
        enhancedDatabaseReporting: true,
      }),
      
      // Logging instrumentation (for Loki)
      new WinstonInstrumentation(),
      
      // HTTP instrumentation
      getNodeAutoInstrumentations({
        '@opentelemetry/instrumentation-fs': { enabled: false },
        '@opentelemetry/instrumentation-dns': { enabled: false },
        '@opentelemetry/instrumentation-express': { enabled: true },
        '@opentelemetry/instrumentation-http': { enabled: true },
        '@opentelemetry/instrumentation-winston': { enabled: true },
      }),
    ],
  });

  await sdk.start();
  console.log('✅ OpenTelemetry initialized');
  console.log(`📊 Metrics: ${OTLP_ENDPOINT}/v1/metrics`);
  console.log(`🔍 Traces: ${OTLP_ENDPOINT}/v1/traces`);
}

export async function shutdownTelemetry() {
  if (!sdk) return;
  try {
    await sdk.shutdown();
    console.log('🧹 Telemetry shutdown');
  } catch (error) {
    console.error('Telemetry shutdown error:', error);
  }
}
```

### 3. Create `src/config/logger.ts`

```typescript
import winston from 'winston';
import LokiTransport from 'winston-loki';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { 
    service: process.env.SERVICE_NAME || 'my-express-app',
    version: process.env.SERVICE_VERSION || '1.0.0'
  },
  transports: [
    // Console transport for development
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    }),
    
    // File transport (backup)
    new winston.transports.File({ 
      filename: 'logs/app.log',
      format: winston.format.json()
    }),

    // Loki transport - sends logs directly to Loki
    new LokiTransport({
      host: process.env.LOKI_URL || 'http://localhost:3100',
      labels: {
        service: process.env.SERVICE_NAME || 'my-express-app',
        environment: process.env.NODE_ENV || 'development',
        version: process.env.SERVICE_VERSION || '1.0.0'
      },
      json: true,
      format: winston.format.json(),
      replaceTimestamp: true,
      onConnectionError: (err) => {
        console.error('Winston Loki connection error:', err);
      }
    })
  ],
});

export { logger };
```

### 4. Update your `server.ts`

```typescript
// IMPORTANT: Import telemetry FIRST, before your app
import { startTelemetry, shutdownTelemetry } from './config/telemetry';

// Start telemetry before importing app
startTelemetry();

import { app } from './app'; // Your Express app

const PORT = process.env.PORT || 3001;

const server = app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`🔗 Health: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received');
  server.close(() => {
    shutdownTelemetry().finally(() => process.exit(0));
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received');
  server.close(() => {
    shutdownTelemetry().finally(() => process.exit(0));
  });
});
```

### 5. Update your `app.ts` with structured logging

```typescript
import express from 'express';
import cors from 'cors';
import { logger } from './config/logger';

const app = express();

// Structured logging middleware
app.use((req, res, next) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip || req.connection.remoteAddress
    });
  });
  
  next();
});

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  logger.info('Health check requested');
  res.json({ 
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: process.env.SERVICE_NAME || 'my-express-app'
  });
});

// Your routes here...

// Error logging
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error('Unhandled error', {
    error: err.message,
    stack: err.stack,
    method: req.method,
    url: req.url
  });
  res.status(500).json({ error: 'Internal server error' });
});

export { app };
```

### 6. Add Environment Variables

Create/update `.env`:

```bash
# Telemetry Configuration
TELEMETRY_ENABLED=true
SERVICE_NAME=my-express-app
SERVICE_VERSION=1.0.0
OTLP_ENDPOINT=http://localhost:4318
METRIC_EXPORT_INTERVAL=5000
NODE_ENV=development

# Loki Configuration
LOG_LEVEL=info
LOKI_URL=http://localhost:3100

# Pyroscope Configuration
PYROSCOPE_ENABLED=true
PYROSCOPE_ENDPOINT=http://localhost:4040

# Application
PORT=3001
```

### 7. Create logs directory

```bash
mkdir -p logs
```

### 8. Start Observability Stack

```bash
# Clone and start LGTM stack
git clone https://github.com/ravnhq/observability-stack.git
cd observability-stack/src
docker-compose up -d

# Access Grafana at http://localhost:3030 (admin/admin)
```

## 📊 View Your Data

### Grafana (http://localhost:3030)

**Traces (Tempo):**
- Go to Explore → Tempo
- Search for service: `my-express-app`
- See HTTP requests and database queries with trace correlation

**Metrics (Prometheus):**
- Go to Explore → Prometheus
- Try these queries:

```promql
# HTTP request rate
rate(http_server_duration_seconds_count{service_name="my-express-app"}[5m])

# HTTP request duration (95th percentile)
histogram_quantile(0.95, rate(http_server_duration_seconds_bucket{service_name="my-express-app"}[5m]))

# Error rate
rate(http_server_duration_seconds_count{service_name="my-express-app",status_code=~"5.."}[5m])
```

**Logs (Loki):**
- Go to Explore → Loki
- Try these queries:

```logql
# All logs for your service
{service="my-express-app"}

# Error logs only
{service="my-express-app"} |= "ERROR"

# HTTP requests with status 500
{service="my-express-app"} | json | statusCode="500"

# Slow requests (>1000ms)
{service="my-express-app"} | json | duration > "1000ms"

# Logs with trace correlation
{service="my-express-app"} | json | trace_id != ""
```

**Profiling (Pyroscope):**
- Go to Explore → Pyroscope
- Select service: `my-express-app`
- View CPU profiles, memory usage, flame graphs

## 🎯 That's It!

Your Express app now automatically captures:
- ✅ **HTTP request metrics** (duration, status codes, paths)
- ✅ **Distributed traces** across your application with correlation IDs
- ✅ **Database query traces** (if using Prisma/PostgreSQL)
- ✅ **Structured logs** sent directly to Loki with trace correlation
- ✅ **CPU/Memory profiling** with Pyroscope
- ✅ **All data unified** in Grafana for visualization and correlation

**Test it:** Make some API calls and check Grafana in 10-15 seconds!