// src/tasks/task.controller.ts
import { Request, Response } from 'express';
import { TaskService } from './task.service';
import { CreateTaskDto, UpdateTaskDto } from './task.dto';

const service = new TaskService();

export class TaskController {
  async getTasks(req: Request, res: Response) {
    const tasks = await service.findAll();
    res.json(tasks);
  }

  async getTaskById(req: Request, res: Response) {
    const id = Number(req.params.id);
    if (Number.isNaN(id)) {
      return res.status(400).json({ message: 'Invalid id' });
    }

    const task = await service.findOne(id);
    if (!task) {
      return res.status(404).json({ message: 'Task not found' });
    }

    res.json(task);
  }

  async createTask(req: Request, res: Response) {
    const body = req.body as CreateTaskDto;

    if (!body.name || !body.date) {
      return res
        .status(400)
        .json({ message: 'name and date are required' });
    }

    const task = await service.create(body);
    res.status(201).json(task);
  }

  async updateTask(req: Request, res: Response) {
    const id = Number(req.params.id);
    if (Number.isNaN(id)) {
      return res.status(400).json({ message: 'Invalid id' });
    }

    const body = req.body as UpdateTaskDto;
    const updated = await service.update(id, body);

    if (!updated) {
      return res.status(404).json({ message: 'Task not found' });
    }

    res.json(updated);
  }

  async deleteTask(req: Request, res: Response) {
    const id = Number(req.params.id);
    if (Number.isNaN(id)) {
      return res.status(400).json({ message: 'Invalid id' });
    }

    const deleted = await service.delete(id);
    if (!deleted) {
      return res.status(404).json({ message: 'Task not found' });
    }

    res.status(204).send();
  }
}