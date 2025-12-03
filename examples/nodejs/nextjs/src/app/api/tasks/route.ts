import { NextResponse } from 'next/server';
import { prisma } from '@/lib/db';
import { logger } from '@/lib/logger';

export async function GET() {
  try {
    logger.info('Fetching all tasks');
    const tasks = await prisma.task.findMany({
      orderBy: { createdAt: 'desc' },
    });
    logger.info({ count: tasks.length }, 'Tasks retrieved successfully');
    return NextResponse.json(tasks);
  } catch (error) {
    logger.error({ error }, 'Failed to fetch tasks');
    return NextResponse.json(
      { error: 'Failed to fetch tasks' },
      { status: 500 }
    );
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    logger.info({ name: body.name, status: body.status }, 'Creating new task');
    
    const task = await prisma.task.create({
      data: {
        name: body.name,
        description: body.description,
        date: new Date(body.date),
        status: body.status || 'PENDING',
      },
    });
    
    logger.info({ taskId: task.id }, 'Task created successfully');
    return NextResponse.json(task, { status: 201 });
  } catch (error) {
    logger.error({ error }, 'Failed to create task');
    return NextResponse.json(
      { error: 'Failed to create task' },
      { status: 500 }
    );
  }
}
