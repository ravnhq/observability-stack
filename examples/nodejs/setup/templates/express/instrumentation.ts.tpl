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

const DEFAULT_OTLP_URL = '__DEFAULT_OTLP_URL__';
const DEFAULT_SERVICE_NAME = '__DEFAULT_SERVICE_NAME__';
const DEFAULT_SERVICE_VERSION = '__DEFAULT_SERVICE_VERSION__';
const DEFAULT_PYROSCOPE_URL = '__DEFAULT_PYROSCOPE_URL__';

const OTEL_COLLECTOR_URL = process.env.OTEL_COLLECTOR_URL || DEFAULT_OTLP_URL;
const PYROSCOPE_ENDPOINT = process.env.PYROSCOPE_ENDPOINT || DEFAULT_PYROSCOPE_URL;
const SERVICE_NAME = process.env.OTEL_SERVICE_NAME || process.env.SERVICE_NAME || DEFAULT_SERVICE_NAME;
const SERVICE_VERSION = process.env.SERVICE_VERSION || DEFAULT_SERVICE_VERSION;
const ENVIRONMENT = process.env.NODE_ENV || 'development';

if (process.env.PYROSCOPE_ENABLED !== 'false') {
  Pyroscope.init({
    serverAddress: PYROSCOPE_ENDPOINT,
    appName: SERVICE_NAME,
    tags: {
      version: SERVICE_VERSION,
      environment: ENVIRONMENT,
    },
  });
  console.log('🔥 Pyroscope profiling enabled');
}

const resource = resourceFromAttributes({
  [ATTR_SERVICE_NAME]: SERVICE_NAME,
  [ATTR_SERVICE_VERSION]: SERVICE_VERSION,
  'deployment.environment': ENVIRONMENT,
});

const traceExporter = new OTLPTraceExporter({
  url: `${OTEL_COLLECTOR_URL}/v1/traces`,
});

const metricExporter = new OTLPMetricExporter({
  url: `${OTEL_COLLECTOR_URL}/v1/metrics`,
});

const logExporter = new OTLPLogExporter({
  url: `${OTEL_COLLECTOR_URL}/v1/logs`,
});

const sdk = new NodeSDK({
  resource,
  traceExporter,
  metricReader: new PeriodicExportingMetricReader({
    exporter: metricExporter,
    exportIntervalMillis: 10000,
  }),
  logRecordProcessor: new BatchLogRecordProcessor(logExporter),
  instrumentations: [
    new PinoInstrumentation({
      logKeys: {
        traceId: 'trace_id',
        spanId: 'span_id',
        traceFlags: 'trace_flags',
      },
    }),
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-fs': { enabled: false },
      '@opentelemetry/instrumentation-pino': { enabled: true },
      '@opentelemetry/instrumentation-http': {
        ignoreIncomingRequestHook: (request) => {
          const ignorePaths = ['/health', '/metrics', '/ready', '/live'];
          return ignorePaths.some((path) => request.url?.includes(path));
        },
      },
    }),
  ],
});

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
