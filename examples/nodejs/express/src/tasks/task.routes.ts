// src/tasks/task.routes.ts
import { Router } from 'express';
import { TaskController } from './task.controller';

const router = Router();
const controller = new TaskController();

router.get('/', controller.getTasks.bind(controller));
router.get('/:id', controller.getTaskById.bind(controller));
router.post('/', controller.createTask.bind(controller));
router.put('/:id', controller.updateTask.bind(controller));
router.delete('/:id', controller.deleteTask.bind(controller));

export { router as taskRoutes };