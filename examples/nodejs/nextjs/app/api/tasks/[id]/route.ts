import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

const notFound = () => NextResponse.json({ error: 'Task not found' }, { status: 404 });

type ParamsContext = { params: Promise<{ id: string }> };

const resolveId = async (context: ParamsContext) => {
  const { id } = await context.params;
  return Number(id);
};

export async function GET(_req: NextRequest, context: ParamsContext) {
  const id = await resolveId(context);
  if (Number.isNaN(id)) {
    return NextResponse.json({ error: 'Invalid id' }, { status: 400 });
  }

  const task = await prisma.task.findUnique({ where: { id } });
  if (!task) {
    return notFound();
  }
  return NextResponse.json(task);
}

export async function PUT(request: NextRequest, context: ParamsContext) {
  const id = await resolveId(context);
  if (Number.isNaN(id)) {
    return NextResponse.json({ error: 'Invalid id' }, { status: 400 });
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

    return NextResponse.json(task);
  } catch (error) {
    console.error('[tasks] Failed to update task', error);
    return NextResponse.json({ error: 'Failed to update task' }, { status: 500 });
  }
}

export async function DELETE(_request: NextRequest, context: ParamsContext) {
  const id = await resolveId(context);
  if (Number.isNaN(id)) {
    return NextResponse.json({ error: 'Invalid id' }, { status: 400 });
  }

  try {
    await prisma.task.delete({ where: { id } });
    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('[tasks] Failed to delete task', error);
    return notFound();
  }
}
