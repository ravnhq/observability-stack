// src/tasks/task.dto.ts
import { TaskStatus } from './task.types';

export interface CreateTaskDto {
  name: string;
  description?: string;
  date: string;        // ISO string in request body
  status?: TaskStatus; // optional, defaults to PENDING
}

export interface UpdateTaskDto {
  name?: string;
  description?: string;
  date?: string;       // ISO string
  status?: TaskStatus;
}