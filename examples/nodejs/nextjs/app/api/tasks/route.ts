import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { startHttpRequestTimer } from '@/lib/metrics';

export async function GET() {
  const stopTimer = startHttpRequestTimer('GET', '/api/tasks');
  try {
    const tasks = await prisma.task.findMany({
      orderBy: { createdAt: 'desc' },
    });
    const response = NextResponse.json(tasks);
    stopTimer(response.status);
    return response;
  } catch (error) {
    console.error('[tasks] Failed to fetch tasks', error);
    const response = NextResponse.json({ error: 'Failed to fetch tasks' }, { status: 500 });
    stopTimer(response.status, 'InternalServerErrorException');
    return response;
  }
}

export async function POST(request: NextRequest) {
  const stopTimer = startHttpRequestTimer('POST', '/api/tasks');
  try {
    const body = await request.json();
    const { name, description, date, status } = body ?? {};

    if (!name || !date) {
      const response = NextResponse.json({ error: 'name and date are required' }, { status: 400 });
      stopTimer(response.status, 'HttpException');
      return response;
    }

    const task = await prisma.task.create({
      data: {
        name,
        description,
        date: new Date(date),
        status,
      },
    });

    const response = NextResponse.json(task, { status: 201 });
    stopTimer(response.status);
    return response;
  } catch (error) {
    console.error('[tasks] Failed to create task', error);
    const response = NextResponse.json({ error: 'Failed to create task' }, { status: 500 });
    stopTimer(response.status, 'InternalServerErrorException');
    return response;
  }
}
