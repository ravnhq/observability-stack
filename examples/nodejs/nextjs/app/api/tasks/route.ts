import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export async function GET() {
  const tasks = await prisma.task.findMany({
    orderBy: { createdAt: 'desc' },
  });
  return NextResponse.json(tasks);
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { name, description, date, status } = body ?? {};

    if (!name || !date) {
      return NextResponse.json({ error: 'name and date are required' }, { status: 400 });
    }

    const task = await prisma.task.create({
      data: {
        name,
        description,
        date: new Date(date),
        status,
      },
    });

    return NextResponse.json(task, { status: 201 });
  } catch (error) {
    console.error('[tasks] Failed to create task', error);
    return NextResponse.json({ error: 'Failed to create task' }, { status: 500 });
  }
}
