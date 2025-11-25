// src/server.ts
// Initialize telemetry BEFORE importing app
import { initTelemetry, shutdownTelemetry } from './config/telemetry';
import dotenv from 'dotenv';
import { app } from './app';

dotenv.config();

// Initialize OpenTelemetry
const sdk = initTelemetry();

const PORT = process.env.PORT || 3000;

const server = app.listen(PORT, () => {
  console.log(`🚀 API listening on port ${PORT}`);
  if (sdk) {
    console.log(`📊 Observability enabled`);
  }
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received');
  server.close(() => {
    if (sdk) shutdownTelemetry(sdk);
  });
});

process.on('SIGINT', async () => {
  console.log('SIGINT received');
  server.close(() => {
    if (sdk) shutdownTelemetry(sdk);
  });
});