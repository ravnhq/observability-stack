import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { OTLPLogExporter } from '@opentelemetry/exporter-logs-otlp-http';
import { resourceFromAttributes } from '@opentelemetry/resources';
import { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION } from '@opentelemetry/semantic-conventions';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { BatchLogRecordProcessor } from '@opentelemetry/sdk-logs';
import { PinoInstrumentation } from '@opentelemetry/instrumentation-pino';
import Pyroscope from '@pyroscope/nodejs';

const OTEL_COLLECTOR_URL = process.env.OTEL_COLLECTOR_URL || 'http://localhost:4318';
const PYROSCOPE_ENDPOINT = process.env.PYROSCOPE_ENDPOINT || 'http://localhost:4040';
const SERVICE_NAME = process.env.OTEL_SERVICE_NAME || process.env.SERVICE_NAME || 'nextjs-app';
const SERVICE_VERSION = process.env.SERVICE_VERSION || '1.0.0';

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

const resource = resourceFromAttributes({
  [ATTR_SERVICE_NAME]: SERVICE_NAME,
  [ATTR_SERVICE_VERSION]: SERVICE_VERSION,
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
    new PinoInstrumentation(),
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-fs': { enabled: false },
      '@opentelemetry/instrumentation-http': {
        ignoreIncomingRequestHook: (request) => {
          const ignorePaths = ['/health', '/_next', '/favicon.ico'];
          return ignorePaths.some((path) => request.url?.includes(path));
        },
      },
    }),
  ],
});

export async function register() {
  // This function is called by Next.js when the instrumentationHook is enabled
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    await sdk.start();
    console.log('OpenTelemetry instrumentation started for Next.js');
  }
}
