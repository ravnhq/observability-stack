import express from 'express';
import cors from 'cors';
import { taskRoutes } from './tasks/task.routes';
import { logger } from './config/logger';

const app = express();

// HTTP request logging middleware
app.use((req, res, next) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    logger.info({
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
    }, 'HTTP Request');
  });
  
  next();
});

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  logger.info('Health check called');
  res.status(200).json({ status: 'ok' });
});

app.use('/tasks', taskRoutes);

// Error logging
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error({ err, method: req.method, url: req.url }, 'Unhandled error');
  res.status(500).json({ error: 'Internal server error' });
});

export { app };