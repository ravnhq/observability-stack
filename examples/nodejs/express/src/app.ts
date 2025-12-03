import express from 'express';
import cors from 'cors';
import { taskRoutes } from './tasks/task.routes';

const app = express();

// Structured logging middleware
app.use((req, res, next) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - startTime;
  });
  
  next();
});

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.use('/tasks', taskRoutes);

// Error logging
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  res.status(500).json({ error: 'Internal server error' });
});

export { app };