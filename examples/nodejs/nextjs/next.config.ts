import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: 'standalone',
  serverExternalPackages: ['pino', 'pino-pretty', '@opentelemetry/api', '@opentelemetry/resources', '@opentelemetry/sdk-node'],
};

export default nextConfig;
