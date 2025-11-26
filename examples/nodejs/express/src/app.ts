import express from 'express';
import cors from 'cors';
import { taskRoutes } from './tasks/task.routes';
import { logger } from './config/logger';

const app = express();

// Structured logging middleware
app.use((req, res, next) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    logger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip || req.connection.remoteAddress
    });
  });
  
  next();
});

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  logger.info('Health check requested');
  res.json({ 
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: process.env.SERVICE_NAME || 'minimal-metrics-api'
  });
});

app.use('/tasks', taskRoutes);

// Error logging
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error('Unhandled error', {
    error: err.message,
    stack: err.stack,
    method: req.method,
    url: req.url
  });
  res.status(500).json({ error: 'Internal server error' });
});

export { app };