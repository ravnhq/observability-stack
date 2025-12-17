import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { startHttpRequestTimer } from '@/lib/metrics';

const notFound = () => NextResponse.json({ error: 'Task not found' }, { status: 404 });

type ParamsContext = { params: Promise<{ id: string }> };

const resolveId = async (context: ParamsContext) => {
  const { id } = await context.params;
  return Number(id);
};

export async function GET(_req: NextRequest, context: ParamsContext) {
  const stopTimer = startHttpRequestTimer('GET', '/api/tasks/{id}');
  const id = await resolveId(context);
  if (Number.isNaN(id)) {
    const response = NextResponse.json({ error: 'Invalid id' }, { status: 400 });
    stopTimer(response.status, 'HttpException');
    return response;
  }

  const task = await prisma.task.findUnique({ where: { id } });
  if (!task) {
    const response = notFound();
    stopTimer(response.status, 'HttpException');
    return response;
  }
  const response = NextResponse.json(task);
  stopTimer(response.status);
  return response;
}

export async function PUT(request: NextRequest, context: ParamsContext) {
  const stopTimer = startHttpRequestTimer('PUT', '/api/tasks/{id}');
  const id = await resolveId(context);
  if (Number.isNaN(id)) {
    const response = NextResponse.json({ error: 'Invalid id' }, { status: 400 });
    stopTimer(response.status, 'HttpException');
    return response;
  }

  try {
    const body = await request.json();
    const { name, description, date, status } = body ?? {};

    const task = await prisma.task.update({
      where: { id },
      data: {
        name,
        description,
        date: date ? new Date(date) : undefined,
        status,
      },
    });

    const response = NextResponse.json(task);
    stopTimer(response.status);
    return response;
  } catch (error) {
    console.error('[tasks] Failed to update task', error);
    const response = NextResponse.json({ error: 'Failed to update task' }, { status: 500 });
    stopTimer(response.status, 'InternalServerErrorException');
    return response;
  }
}

export async function DELETE(_request: NextRequest, context: ParamsContext) {
  const stopTimer = startHttpRequestTimer('DELETE', '/api/tasks/{id}');
  const id = await resolveId(context);
  if (Number.isNaN(id)) {
    const response = NextResponse.json({ error: 'Invalid id' }, { status: 400 });
    stopTimer(response.status, 'HttpException');
    return response;
  }

  try {
    await prisma.task.delete({ where: { id } });
    const response = NextResponse.json({ success: true });
    stopTimer(response.status);
    return response;
  } catch (error) {
    console.error('[tasks] Failed to delete task', error);
    const response = notFound();
    stopTimer(response.status, 'HttpException');
    return response;
  }
}
