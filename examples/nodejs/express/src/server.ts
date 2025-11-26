// src/server.ts
// IMPORTANT: Initialize telemetry BEFORE importing the app
import { startTelemetry, shutdownTelemetry } from './config/telemetry';

// Start telemetry first
startTelemetry();

import { app } from './app';

const PORT = process.env.PORT || 3001;

const server = app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`🔗 API available at: http://localhost:${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    shutdownTelemetry().finally(() => process.exit(0));
  });
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => {
    shutdownTelemetry().finally(() => process.exit(0));
  });
});