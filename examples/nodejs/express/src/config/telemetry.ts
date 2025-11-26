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

dotenv.config();

const TELEMETRY_ENABLED = process.env.TELEMETRY_ENABLED !== 'false';
const SERVICE_NAME = process.env.SERVICE_NAME || 'minimal-metrics-api';
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

  const traceExporter = new OTLPTraceExporter({ url: `${OTLP_ENDPOINT}/v1/traces` });
  const metricExporter = new OTLPMetricExporter({ url: `${OTLP_ENDPOINT}/v1/metrics` });

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
      new PgInstrumentation({ enhancedDatabaseReporting: true }),
      new PrismaInstrumentation(),
      
      // Logging instrumentation (for Loki)
      new WinstonInstrumentation(),
      
      // HTTP instrumentation
      getNodeAutoInstrumentations({
        '@opentelemetry/instrumentation-fs': { enabled: false },
        '@opentelemetry/instrumentation-dns': { enabled: false },
        '@opentelemetry/instrumentation-net': { enabled: false },
        '@opentelemetry/instrumentation-express': { enabled: true },
        '@opentelemetry/instrumentation-http': { enabled: true },
        '@opentelemetry/instrumentation-winston': { enabled: true },
      }),
    ],
  });

  await sdk.start();
  console.log('✅ OpenTelemetry initialized successfully');
  console.log(`📊 Metrics: ${OTLP_ENDPOINT}/v1/metrics`);
  console.log(`🔍 Traces: ${OTLP_ENDPOINT}/v1/traces`);
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

process.on('SIGTERM', () => shutdownTelemetry().finally(() => process.exit(0)));
process.on('SIGINT', () => shutdownTelemetry().finally(() => process.exit(0)));
