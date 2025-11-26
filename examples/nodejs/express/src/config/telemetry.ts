// src/telemetry.ts
import dotenv from 'dotenv';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { defaultResource, resourceFromAttributes } from '@opentelemetry/resources';
import { PrismaInstrumentation } from '@prisma/instrumentation';

// ========== LOAD ENV FIRST ==========
dotenv.config();
console.log('🔧 Debug: After dotenv.config()...');
console.log('🔧 process.env.TELEMETRY_ENABLED:', process.env.TELEMETRY_ENABLED);
console.log('🔧 process.env.SERVICE_NAME:', process.env.SERVICE_NAME);
console.log('🔧 process.env.OTLP_ENDPOINT:', process.env.OTLP_ENDPOINT);

const TELEMETRY_ENABLED = process.env.TELEMETRY_ENABLED !== 'false';
const SERVICE_NAME = process.env.SERVICE_NAME || 'minimal-metrics-api';
const SERVICE_VERSION = process.env.SERVICE_VERSION || '1.0.0';
const OTLP_ENDPOINT = process.env.OTLP_ENDPOINT || 'http://localhost:4318';
const METRIC_EXPORT_INTERVAL = Number(process.env.METRIC_EXPORT_INTERVAL) || 5000;

// Opcional: log para debugging
console.log(`[Telemetry] Enabled: ${TELEMETRY_ENABLED}`);
console.log(`[Telemetry] Endpoint: ${OTLP_ENDPOINT}`);
console.log(`[Telemetry] Service: ${SERVICE_NAME} v${SERVICE_VERSION}`);

let sdk: NodeSDK | null = null;

export async function startTelemetry() {
  if (!TELEMETRY_ENABLED) {
    console.log('⚠️  Telemetry is disabled. Skipping OpenTelemetry initialization.');
    return;
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
      new PrismaInstrumentation(),
      getNodeAutoInstrumentations({
        '@opentelemetry/instrumentation-fs': { enabled: false },
        '@opentelemetry/instrumentation-dns': { enabled: false },
        '@opentelemetry/instrumentation-net': { enabled: false },
        '@opentelemetry/instrumentation-express': { enabled: true },
        '@opentelemetry/instrumentation-http': { enabled: true },
      }),
    ],
  });

  sdk.start();
  console.log('✅ OpenTelemetry initialized successfully');
  console.log(`🎯 Service Name: ${SERVICE_NAME}`);
  console.log(`📡 OTLP Traces: ${OTLP_ENDPOINT}/v1/traces`);
  console.log(`📊 OTLP Metrics: ${OTLP_ENDPOINT}/v1/metrics`);
}

export async function shutdownTelemetry() {
  if (!TELEMETRY_ENABLED || !sdk) return;
  try {
    await sdk.shutdown();
    console.log('🧹 OpenTelemetry shutdown completed');
  } catch (error) {
    console.error('Error shutting down telemetry:', error);
  }
}

// Graceful shutdown
process.on('SIGTERM', () => shutdownTelemetry().finally(() => process.exit(0)));
process.on('SIGINT', () => shutdownTelemetry().finally(() => process.exit(0)));
