import Link from 'next/link';
import { prisma } from '@/lib/prisma';

export const dynamic = 'force-dynamic';

const statusColors: Record<string, string> = {
  PENDING: 'bg-yellow-100 text-yellow-900',
  IN_PROGRESS: 'bg-blue-100 text-blue-900',
  DONE: 'bg-green-100 text-green-900',
};

async function getTasks() {
  try {
    return await prisma.task.findMany({ orderBy: { createdAt: 'desc' } });
  } catch (error) {
    console.error('[tasks] Failed to load tasks', error);
    return [];
  }
}

export default async function Home() {
  const tasks = await getTasks();

  return (
    <main className="mx-auto flex min-h-screen max-w-5xl flex-col gap-10 bg-white px-6 py-12 font-sans text-zinc-900">
      <header className="space-y-2">
        <p className="text-sm uppercase tracking-wide text-zinc-500">Next.js + Prisma</p>
        <h1 className="text-4xl font-semibold">Tasks dashboard</h1>
        <p className="text-base text-zinc-600">
          This demo uses a PostgreSQL database via Prisma Client and exposes CRUD endpoints under{' '}
          <code className="rounded bg-zinc-100 px-1.5 py-0.5 text-sm">/api/tasks</code>.
        </p>
      </header>

      <section className="rounded-2xl border border-zinc-200 bg-zinc-50 p-6">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-medium">Recent tasks</h2>
          <Link className="text-sm font-medium text-blue-600" href="https://www.postman.com/" target="_blank">
            Open with your API client →
          </Link>
        </div>
        <ol className="mt-6 space-y-4">
          {tasks.length === 0 && <p className="text-sm text-zinc-500">Run POST /api/tasks to add your first task.</p>}
          {tasks.map((task) => (
            <li key={task.id} className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-lg font-semibold">{task.name}</h3>
                  {task.description && <p className="text-sm text-zinc-500">{task.description}</p>}
                </div>
                <span className={`rounded-full px-3 py-1 text-xs font-semibold ${statusColors[task.status] ?? 'bg-zinc-100 text-zinc-700'}`}>
                  {task.status.replace('_', ' ')}
                </span>
              </div>
              <p className="mt-3 text-sm text-zinc-600">
                Target date: {new Date(task.date).toLocaleDateString()} · Created {new Date(task.createdAt).toLocaleString()}
              </p>
            </li>
          ))}
        </ol>
      </section>

      <section className="rounded-2xl border border-dashed border-zinc-300 p-6">
        <h2 className="text-lg font-semibold">Quick API reference</h2>
        <ul className="mt-4 list-disc space-y-2 pl-5 text-sm text-zinc-600">
          <li><code>GET /api/tasks</code> · List all tasks</li>
          <li><code>POST /api/tasks</code> · Create a task, body: <code>{`{ "name": "", "date": "2025-01-01" }`}</code></li>
          <li><code>GET /api/tasks/:id</code> · Retrieve a single task</li>
          <li><code>PUT /api/tasks/:id</code> · Update any field</li>
          <li><code>DELETE /api/tasks/:id</code> · Remove a task</li>
        </ul>
      </section>
    </main>
  );
}
