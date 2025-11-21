// src/tasks/task.service.ts
import { prisma } from '../config/db';
import { Task } from './task.types';
import { CreateTaskDto, UpdateTaskDto } from './task.dto';

export class TaskService {
  async findAll(): Promise<Task[]> {
    return prisma.task.findMany({
      orderBy: { createdAt: 'desc' },
    }) as unknown as Task[];
  }

  async findOne(id: number): Promise<Task | null> {
    return prisma.task.findUnique({
      where: { id },
    }) as unknown as Task | null;
  }

  async create(data: CreateTaskDto): Promise<Task> {
    const { name, description, date, status } = data;

    return prisma.task.create({
      data: {
        name,
        description,
        date: new Date(date),
        status: status ?? 'PENDING',
      },
    }) as unknown as Task;
  }

  async update(id: number, data: UpdateTaskDto): Promise<Task | null> {
    const existing = await this.findOne(id);
    if (!existing) return null;

    const { name, description, date, status } = data;

    return prisma.task.update({
      where: { id },
      data: {
        name: name ?? existing.name,
        description: description ?? existing.description ?? undefined,
        date: date ? new Date(date) : existing.date,
        status: status ?? existing.status,
      },
    }) as unknown as Task;
  }

  async delete(id: number): Promise<boolean> {
    const existing = await this.findOne(id);
    if (!existing) return false;

    await prisma.task.delete({ where: { id } });
    return true;
  }
}