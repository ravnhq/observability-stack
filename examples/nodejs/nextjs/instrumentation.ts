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
    exportIntervalMillis: 5000, // Export metrics every 5 seconds
  }),
  logRecordProcessor: new BatchLogRecordProcessor(logExporter),
  instrumentations: [
    new PinoInstrumentation(),
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-fs': { enabled: false },
      '@opentelemetry/instrumentation-http': {
        enabled: true,
        ignoreIncomingRequestHook: (request) => {
          // Only ignore static assets, allow all API routes
          const ignorePaths = ['/_next/static', '/_next/image', '/favicon.ico', '/__nextjs'];
          return ignorePaths.some((path) => request.url?.includes(path));
        },
      },
    }),
  ],
});

export async function register() {
  console.log('🔍 Register function called');
  console.log('🔍 NEXT_RUNTIME:', process.env.NEXT_RUNTIME);
  console.log('🔍 NODE_ENV:', process.env.NODE_ENV);
  console.log('🔍 OTEL_COLLECTOR_URL:', OTEL_COLLECTOR_URL);
  
  // Start SDK regardless of runtime for Next.js
  try {
    await sdk.start();
    console.log('✅ OpenTelemetry SDK started successfully');
    console.log('📊 Traces -> ', `${OTEL_COLLECTOR_URL}/v1/traces`);
    console.log('📊 Metrics -> ', `${OTEL_COLLECTOR_URL}/v1/metrics`);
    console.log('📊 Logs -> ', `${OTEL_COLLECTOR_URL}/v1/logs`);
    console.log('🏷️  Service:', SERVICE_NAME, 'Version:', SERVICE_VERSION);
    console.log('🔥 Pyroscope:', process.env.PYROSCOPE_ENABLED !== 'false' ? 'enabled' : 'disabled');
    
    // Test trace
    console.log('🧪 Instrumentation is ready - make API requests to generate telemetry');
  } catch (error) {
    console.error('❌ Failed to start OpenTelemetry SDK:', error);
  }
}
