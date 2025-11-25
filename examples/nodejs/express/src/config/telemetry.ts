import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { PrismaInstrumentation } from '@prisma/instrumentation';
import { PgInstrumentation } from '@opentelemetry/instrumentation-pg';

// Environment configuration
const TELEMETRY_CONFIG = {
  enabled: process.env.TELEMETRY_ENABLED !== 'false',
  serviceName: process.env.SERVICE_NAME || 'minimal-metrics-api',
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
      new PrismaInstrumentation(),
      new PgInstrumentation(),
    ],
  });

  sdk.start();
  
  console.log(`📊 OpenTelemetry initialized for ${TELEMETRY_CONFIG.serviceName}`);
  console.log(`🎯 OTLP Endpoint: ${TELEMETRY_CONFIG.otlpEndpoint}`);
  console.log(`⏱️  Export Interval: ${TELEMETRY_CONFIG.exportInterval}ms`);
  
  return sdk;
};

// Graceful shutdown
export const shutdownTelemetry = async (sdk: NodeSDK) => {
  try {
    await sdk.shutdown();
    console.log('📊 OpenTelemetry terminated');
  } catch (error) {
    console.error('Error terminating OpenTelemetry SDK', error);
  }
};
