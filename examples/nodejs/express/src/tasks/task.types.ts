// src/tasks/task.types.ts
export type TaskStatus = 'PENDING' | 'IN_PROGRESS' | 'DONE';

export interface Task {
  id: number;
  name: string;
  description?: string | null;
  date: Date;
  status: TaskStatus;
  createdAt: Date;
  updatedAt: Date;
}