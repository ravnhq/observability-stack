# Express.js Observability Implementation Guide

A complete guide to add **OpenTelemetry** observability (metrics, traces, logs) to any Express.js project for integration with **Grafana**, **Tempo**, **Loki**, and **Mimir**.

## 🎯 What You'll Get

- **Automatic HTTP instrumentation** (request duration, status codes, paths)
- **Distributed tracing** across services
- **Custom metrics** for business logic
- **Structured logging** with correlation
- **Ready for Grafana dashboards**

## 🚀 Step-by-Step Implementation

### 1. Install OpenTelemetry Dependencies

```bash
npm install @opentelemetry/sdk-node \
            @opentelemetry/auto-instrumentations-node \
            @opentelemetry/exporter-trace-otlp-http \
            @opentelemetry/exporter-metrics-otlp-http \
            @opentelemetry/sdk-metrics \
            @opentelemetry/api \
            dotenv
```

### 2. Create Telemetry Configuration

Create `src/config/telemetry.ts`:

```typescript
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';

// Environment configuration
const TELEMETRY_CONFIG = {
  enabled: process.env.TELEMETRY_ENABLED !== 'false',
  serviceName: process.env.SERVICE_NAME || 'my-express-app',
  serviceVersion: process.env.SERVICE_VERSION || '1.0.0',
  otlpEndpoint: process.env.OTLP_ENDPOINT || 'http://localhost:4318',
  exportInterval: parseInt(process.env.METRIC_EXPORT_INTERVAL || '10000'),
  environment: process.env.NODE_ENV || 'development',
};

// Initialize OpenTelemetry SDK
export const initTelemetry = () => {
  if (!TELEMETRY_CONFIG.enabled) {
    console.log('📊 Telemetry disabled via TELEMETRY_ENABLED=false');
    return null;
  }

  const sdk = new NodeSDK({
    traceExporter: new OTLPTraceExporter({
      url: `${TELEMETRY_CONFIG.otlpEndpoint}/v1/traces`,
    }),
    metricReader: new PeriodicExportingMetricReader({
      exporter: new OTLPMetricExporter({
        url: `${TELEMETRY_CONFIG.otlpEndpoint}/v1/metrics`,
      }),
      exportIntervalMillis: TELEMETRY_CONFIG.exportInterval,
    }),
    instrumentations: [
      getNodeAutoInstrumentations({
        '@opentelemetry/instrumentation-http': { enabled: true },
        '@opentelemetry/instrumentation-express': { enabled: true },
        '@opentelemetry/instrumentation-fs': { enabled: false },
        '@opentelemetry/instrumentation-dns': { enabled: false },
      }),
    ],
  });

  sdk.start();
  
  console.log(`📊 OpenTelemetry initialized for ${TELEMETRY_CONFIG.serviceName}`);
  console.log(`🎯 OTLP Endpoint: ${TELEMETRY_CONFIG.otlpEndpoint}`);
  console.log(`⏱️  Export Interval: ${TELEMETRY_CONFIG.exportInterval}ms`);
  
  return sdk;
};

// Graceful shutdown
export const shutdownTelemetry = async (sdk: NodeSDK | null) => {
  if (!sdk) return;
  
  try {
    await sdk.shutdown();
    console.log('📊 OpenTelemetry terminated');
  } catch (error) {
    console.error('Error terminating OpenTelemetry SDK', error);
  }
};
```

### 3. Update Your Server Entry Point

Modify your main server file (e.g., `server.ts` or `index.ts`):

```typescript
// ⚠️ IMPORTANT: Initialize telemetry BEFORE importing your app
import { initTelemetry, shutdownTelemetry } from './config/telemetry';

import dotenv from 'dotenv';
import { app } from './app'; // Your Express app

dotenv.config();

// Initialize OpenTelemetry
const sdk = initTelemetry();

const PORT = process.env.PORT || 3000;

const server = app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  if (sdk) {
    console.log(`📊 Observability enabled`);
  }
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received');
  server.close(() => {
    shutdownTelemetry(sdk);
  });
});

process.on('SIGINT', async () => {
  console.log('SIGINT received');
  server.close(() => {
    shutdownTelemetry(sdk);
  });
});
```

### 4. Add Environment Variables

Create or update your `.env` file:

```bash
# Telemetry Configuration
TELEMETRY_ENABLED=true
SERVICE_NAME=my-express-app
SERVICE_VERSION=1.0.0
OTLP_ENDPOINT=http://localhost:4318
METRIC_EXPORT_INTERVAL=10000
NODE_ENV=development
```

### 5. Optional: Add Request Logging Middleware

Add to your `app.ts` for enhanced visibility:

```typescript
// Simple request logging middleware
app.use((req, res, next) => {
  const startTime = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    console.log(`${req.method} ${req.path} - ${res.statusCode} (${duration}ms)`);
  });
  next();
});
```

## 🐳 Setup Observability Stack

### Option 1: Use RAVN Observability Stack (Recommended)

```bash
# Clone the observability stack
git clone https://github.com/ravnhq/observability-stack.git
cd observability-stack/src

# Start all services (Grafana, Loki, Mimir, Tempo)
docker-compose up -d

# Access Grafana at http://localhost:3030
# Login: admin/admin
```

### Option 2: Manual Docker Compose

Create `docker-compose.observability.yml`:

```yaml
version: "3.9"
services:
  grafana-lgtm:
    image: grafana/otel-lgtm:latest
    ports:
      - "3030:3000"   # Grafana UI
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
      - "3100:3100"   # Loki
      - "9090:9090"   # Prometheus/Mimir
      - "9411:9411"   # Tempo
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
```

```bash
docker-compose -f docker-compose.observability.yml up -d
```

## 📊 View Your Metrics

### 1. Access Grafana
- URL: **http://localhost:3030**
- Login: **admin/admin**

### 2. Explore Data
Go to **Explore** and try these queries:

**HTTP Request Rate:**
```promql
rate(http_server_duration_seconds_count[5m])
```

**HTTP Request Duration (95th percentile):**
```promql
histogram_quantile(0.95, rate(http_server_duration_seconds_bucket[5m]))
```

**Error Rate:**
```promql
rate(http_server_duration_seconds_count{status_code=~"5.."}[5m])
```

### 3. Create Dashboard
1. Go to **Dashboards** → **New Dashboard**
2. Add panels with the queries above
3. Save your dashboard

## 🔧 Advanced Configuration

### Custom Business Metrics

```typescript
import { metrics } from '@opentelemetry/api';

// Create a meter
const meter = metrics.getMeter('my-app-business-metrics');

// Counter for user signups
const signupCounter = meter.createCounter('user_signups_total');

// Histogram for order values
const orderValueHistogram = meter.createHistogram('order_value_dollars');

// Usage in your business logic
app.post('/api/users', (req, res) => {
  // Your user creation logic...
  
  signupCounter.add(1, { source: 'web' });
  res.json(user);
});

app.post('/api/orders', (req, res) => {
  // Your order creation logic...
  
  orderValueHistogram.record(order.total, { 
    payment_method: order.paymentMethod 
  });
  res.json(order);
});
```

### Database Instrumentation

For automatic database tracing, install specific instrumentations:

```bash
# PostgreSQL
npm install @opentelemetry/instrumentation-pg

# MySQL
npm install @opentelemetry/instrumentation-mysql

# MongoDB
npm install @opentelemetry/instrumentation-mongodb

# Prisma (experimental)
npm install @prisma/instrumentation
```

Add to your telemetry config:

```typescript
instrumentations: [
  getNodeAutoInstrumentations({
    '@opentelemetry/instrumentation-http': { enabled: true },
    '@opentelemetry/instrumentation-express': { enabled: true },
    '@opentelemetry/instrumentation-pg': { enabled: true },
    // ... other instrumentations
  }),
],
```

## 🚀 Production Considerations

### Environment-Specific Configuration

```bash
# Development
TELEMETRY_ENABLED=true
OTLP_ENDPOINT=http://localhost:4318
METRIC_EXPORT_INTERVAL=5000

# Staging
TELEMETRY_ENABLED=true
OTLP_ENDPOINT=https://staging-observability.company.com
METRIC_EXPORT_INTERVAL=30000

# Production
TELEMETRY_ENABLED=true
OTLP_ENDPOINT=https://observability.company.com
METRIC_EXPORT_INTERVAL=60000
```

### Performance Optimization

```typescript
// Sampling for high-traffic applications
instrumentations: [
  getNodeAutoInstrumentations({
    '@opentelemetry/instrumentation-http': { 
      enabled: true,
      requestHook: (span, request) => {
        // Add custom attributes
        span.setAttributes({
          'http.user_agent': request.headers['user-agent'],
        });
      },
    },
  }),
],
```

## 🔍 Troubleshooting

### Check if Telemetry is Working

```bash
# Test OTLP endpoint
curl -v http://localhost:4318/v1/metrics

# Check Prometheus metrics
curl http://localhost:9090/api/v1/label/__name__/values

# View container logs
docker logs grafana-lgtm
```

### Common Issues

1. **No metrics appearing**: Check `OTLP_ENDPOINT` and ensure observability stack is running
2. **High CPU usage**: Increase `METRIC_EXPORT_INTERVAL` or add sampling
3. **Memory leaks**: Ensure proper SDK shutdown in process handlers

## 📚 Next Steps

1. **Custom Dashboards**: Create specific dashboards for your business metrics
2. **Alerting**: Set up alerts for error rates and performance degradation
3. **Log Correlation**: Add structured logging with trace correlation
4. **Multi-Service**: Extend to microservices with distributed tracing

---

**🎉 Your Express.js app is now fully observable! Monitor, debug, and optimize with confidence.**