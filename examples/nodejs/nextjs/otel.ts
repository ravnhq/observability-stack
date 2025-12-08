import type { NodeSDK } from '@opentelemetry/sdk-node';

const DEFAULT_OTLP_URL = 'http://localhost:4318';
const DEFAULT_SERVICE_NAME = 'nextjs-app';
const DEFAULT_SERVICE_VERSION = '1.0.0';

const OTEL_COLLECTOR_URL = process.env.OTEL_COLLECTOR_URL || DEFAULT_OTLP_URL;
const SERVICE_NAME = process.env.OTEL_SERVICE_NAME || process.env.SERVICE_NAME || DEFAULT_SERVICE_NAME;
const SERVICE_VERSION = process.env.SERVICE_VERSION || DEFAULT_SERVICE_VERSION;
const ENVIRONMENT = process.env.NODE_ENV || 'development';

let sdk: NodeSDK | null = null;
let sdkStarted = false;

async function buildSdk(): Promise<NodeSDK> {
  if (sdk) {
    return sdk;
  }

  const [
    { NodeSDK },
    { OTLPTraceExporter },
    { OTLPMetricExporter },
    { OTLPLogExporter },
    { resourceFromAttributes },
    { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION },
    { PeriodicExportingMetricReader },
    { BatchLogRecordProcessor },
    { PinoInstrumentation },
    { HttpInstrumentation },
  ] = await Promise.all([
    import('@opentelemetry/sdk-node'),
    import('@opentelemetry/exporter-trace-otlp-http'),
    import('@opentelemetry/exporter-metrics-otlp-http'),
    import('@opentelemetry/exporter-logs-otlp-http'),
    import('@opentelemetry/resources'),
    import('@opentelemetry/semantic-conventions'),
    import('@opentelemetry/sdk-metrics'),
    import('@opentelemetry/sdk-logs'),
    import('@opentelemetry/instrumentation-pino'),
    import('@opentelemetry/instrumentation-http'),
  ]);

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

  sdk = new NodeSDK({
    resource,
    traceExporter,
    metricReader: new PeriodicExportingMetricReader({
      exporter: metricExporter,
      exportIntervalMillis: 5000,
    }),
    logRecordProcessor: new BatchLogRecordProcessor(logExporter),
    instrumentations: [
      new PinoInstrumentation(),
      new HttpInstrumentation({
        ignoreIncomingRequestHook: (request) => {
          const ignorePaths = ['/_next/static', '/_next/image', '/favicon.ico', '/__nextjs'];
          return ignorePaths.some((path) => request.url?.includes(path));
        },
      }),
    ],
  });

  return sdk;
}

export async function startNodeTelemetry() {
  const nodeSdk = await buildSdk();

  if (sdkStarted) {
    return;
  }

  try {
    await nodeSdk.start();
    sdkStarted = true;
    console.log(`[otel] SDK started for ${SERVICE_NAME} -> ${OTEL_COLLECTOR_URL}`);
  } catch (error) {
    console.error('[otel] Failed to start OpenTelemetry SDK:', error);
  }
}
