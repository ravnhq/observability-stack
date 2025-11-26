import winston from 'winston';
import LokiTransport from 'winston-loki';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { 
    service: process.env.SERVICE_NAME || 'minimal-metrics-api',
    version: process.env.SERVICE_VERSION || '1.0.0'
  },
  transports: [
    // Console transport for development
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    }),
    
    // File transport (backup)
    new winston.transports.File({ 
      filename: 'logs/app.log',
      format: winston.format.json()
    }),

    // Loki transport - sends logs directly to Loki
    new LokiTransport({
      host: process.env.LOKI_URL || 'http://localhost:3100',
      labels: {
        service: process.env.SERVICE_NAME || 'minimal-metrics-api',
        environment: process.env.NODE_ENV || 'development',
        version: process.env.SERVICE_VERSION || '1.0.0'
      },
      json: true,
      format: winston.format.json(),
      replaceTimestamp: true,
      onConnectionError: (err) => {
        console.error('Winston Loki connection error:', err);
      }
    })
  ],
});

export { logger };