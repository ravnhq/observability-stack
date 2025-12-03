import pino from 'pino';

// Minimalistic Pino logger for Next.js
export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  base: {
    service: process.env.SERVICE_NAME || 'nextjs-app',
    env: process.env.NODE_ENV || 'development',
  },
});
