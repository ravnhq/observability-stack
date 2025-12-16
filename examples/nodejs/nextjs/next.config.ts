import type { NextConfig } from "next";

const serverExternalPackages = [
  'pino',
  'pino-pretty',
  '@opentelemetry/api',
  '@opentelemetry/resources',
  '@opentelemetry/sdk-node',
  '@opentelemetry/auto-instrumentations-node',
  '@opentelemetry/exporter-trace-otlp-http',
  '@opentelemetry/exporter-metrics-otlp-http',
  '@opentelemetry/exporter-logs-otlp-http',
  '@opentelemetry/sdk-logs',
  '@opentelemetry/sdk-metrics',
  '@opentelemetry/semantic-conventions',
  '@opentelemetry/instrumentation-pino',
  '@opentelemetry/instrumentation-http',
  '@opentelemetry/otlp-exporter-base',
  '@opentelemetry/otlp-grpc-exporter-base',
  '@opentelemetry/exporter-trace-otlp-grpc',
  '@opentelemetry/exporter-logs-otlp-grpc',
  '@opentelemetry/exporter-metrics-otlp-grpc',
  '@opentelemetry/exporter-prometheus',
  '@grpc/grpc-js',
  '@grpc/proto-loader',
  'protobufjs',
];

const nextConfig: NextConfig = {
  output: 'standalone',
  serverExternalPackages,
  turbopack: {},
  webpack: (config, { isServer }) => {
    if (isServer) {
      const forcedExternals = new Set(serverExternalPackages);
      const externalHandler = (context: unknown, request?: string, callback?: (err?: Error, result?: string) => void) => {
        if (request && forcedExternals.has(request)) {
          return callback?.(undefined, `commonjs ${request}`);
        }

        if (callback) {
          return callback();
        }

        return undefined;
      };

      if (Array.isArray(config.externals)) {
        config.externals.push(externalHandler);
      } else if (config.externals) {
        config.externals = [config.externals, externalHandler];
      } else {
        config.externals = [externalHandler];
      }
    }

    return config;
  },
};

export default nextConfig;
