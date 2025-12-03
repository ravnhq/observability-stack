import { NextResponse } from 'next/server';
import { prisma } from '@/lib/db';
import { logger } from '@/lib/logger';

type Params = {
  params: Promise<{
    id: string;
  }>;
};

export async function GET(request: Request, { params }: Params) {
  try {
    const { id: idStr } = await params;
    const id = parseInt(idStr);
    logger.info({ taskId: id }, 'Fetching task by ID');
    
    const task = await prisma.task.findUnique({
      where: { id },
    });
    
    if (!task) {
      logger.warn({ taskId: id }, 'Task not found');
      return NextResponse.json(
        { error: 'Task not found' },
        { status: 404 }
      );
    }
    
    logger.info({ taskId: id }, 'Task retrieved successfully');
    return NextResponse.json(task);
  } catch (error) {
    logger.error({ error }, 'Failed to fetch task');
    return NextResponse.json(
      { error: 'Failed to fetch task' },
      { status: 500 }
    );
  }
}

export async function PUT(request: Request, { params }: Params) {
  try {
    const { id: idStr } = await params;
    const id = parseInt(idStr);
    const body = await request.json();
    logger.info({ taskId: id, updates: body }, 'Updating task');
    
    const task = await prisma.task.update({
      where: { id },
      data: {
        name: body.name,
        description: body.description,
        date: body.date ? new Date(body.date) : undefined,
        status: body.status,
      },
    });
    
    logger.info({ taskId: id }, 'Task updated successfully');
    return NextResponse.json(task);
  } catch (error) {
    logger.error({ error }, 'Failed to update task');
    return NextResponse.json(
      { error: 'Failed to update task' },
      { status: 500 }
    );
  }
}

export async function DELETE(request: Request, { params }: Params) {
  try {
    const { id: idStr } = await params;
    const id = parseInt(idStr);
    logger.info({ taskId: id }, 'Deleting task');
    
    await prisma.task.delete({
      where: { id },
    });
    
    logger.info({ taskId: id }, 'Task deleted successfully');
    return NextResponse.json({ success: true });
  } catch (error) {
    logger.error({ error }, 'Failed to delete task');
    return NextResponse.json(
      { error: 'Failed to delete task' },
      { status: 500 }
    );
  }
}
