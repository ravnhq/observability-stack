import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { OTLPLogExporter } from '@opentelemetry/exporter-logs-otlp-http';
import { resourceFromAttributes } from '@opentelemetry/resources';
import { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION } from '@opentelemetry/semantic-conventions';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { BatchLogRecordProcessor } from '@opentelemetry/sdk-logs';

const OTEL_COLLECTOR_URL = process.env.OTEL_COLLECTOR_URL || 'http://localhost:4318';

const resource = resourceFromAttributes({
  [ATTR_SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'nestjs-app',
  [ATTR_SERVICE_VERSION]: process.env.npm_package_version || '1.0.0',
  'deployment.environment': process.env.NODE_ENV || 'development',
});

// Trace exporter - sends to Tempo via OTLP
const traceExporter = new OTLPTraceExporter({
  url: `${OTEL_COLLECTOR_URL}/v1/traces`,
});

// Metrics exporter - sends to Prometheus/Mimir via OTLP
const metricExporter = new OTLPMetricExporter({
  url: `${OTEL_COLLECTOR_URL}/v1/metrics`,
});

// Logs exporter - sends to Loki via OTLP
const logExporter = new OTLPLogExporter({
  url: `${OTEL_COLLECTOR_URL}/v1/logs`,
});

const sdk = new NodeSDK({
  resource,
  traceExporter,
  metricReader: new PeriodicExportingMetricReader({
    exporter: metricExporter,
    exportIntervalMillis: 10000, // Export metrics every 10 seconds
  }),
  logRecordProcessor: new BatchLogRecordProcessor(logExporter),
  instrumentations: [
    getNodeAutoInstrumentations({
      // Disable fs instrumentation to reduce noise
      '@opentelemetry/instrumentation-fs': { enabled: false },
      // Configure HTTP instrumentation
      '@opentelemetry/instrumentation-http': {
        ignoreIncomingRequestHook: (request) => {
          // Ignore health check endpoints
          const ignorePaths = ['/health', '/metrics', '/ready', '/live'];
          return ignorePaths.some((path) => request.url?.includes(path));
        },
      },
    }),
  ],
});

// Graceful shutdown
process.on('SIGTERM', () => {
  sdk
    .shutdown()
    .then(() => console.log('OpenTelemetry SDK shut down successfully'))
    .catch((error) => console.error('Error shutting down OpenTelemetry SDK', error))
    .finally(() => process.exit(0));
});

export function startInstrumentation() {
  sdk.start();
  console.log('OpenTelemetry instrumentation started');
}