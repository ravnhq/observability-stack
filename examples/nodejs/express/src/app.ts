// src/app.ts
import express from 'express';
import cors from 'cors';
import { taskRoutes } from './tasks/task.routes';

const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/tasks', taskRoutes);

export { app };