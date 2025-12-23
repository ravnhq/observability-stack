## Overview

This example demonstrates how to build a Next.js 16 application with:

- Prisma + PostgreSQL backing a simple Tasks CRUD API (`/api/tasks`)
- OpenTelemetry and Pyroscope instrumentation (see `instrumentation.ts` / `otel.ts`)
- Dockerfile + docker-compose stack that mirrors the Express example in this repo

Open [http://localhost:3000](http://localhost:3000) to view the dashboard that lists tasks sourced from PostgreSQL.

## Requirements

- Node.js 18+
- Docker + Docker Compose (for the containerized workflow)

## Local development

1. Copy `.env.example` to `.env` and update `DATABASE_URL` if needed.
2. Start a Postgres instance (or use the provided docker-compose stack below).
3. Run the migrations and generate the Prisma client:

	```bash
	npm install
	npm run prisma:generate
	npm run prisma:migrate:dev --name init
	```

4. Start the Next.js dev server:

	```bash
	npm run dev
	```

5. Use any API client (or `curl`) to call the CRUD endpoints:

	```bash
	curl -X POST http://localhost:3000/api/tasks \
	  -H 'Content-Type: application/json' \
	  -d '{"name":"Ship metrics","date":"2025-01-01"}'
	```

## Production build note (Next.js 16)

This example includes a custom `webpack` configuration in `next.config.ts` (it forces a set of server-side packages to remain external).
In Next.js 16, Turbopack is enabled by default and Next will error if it sees a `webpack` config without an explicit bundler choice.

To keep builds deterministic, `package.json` uses:

- `next build --webpack`

## Docker workflow

The included `Dockerfile` builds a production Next.js image. The accompanying `docker-compose.yaml` stands up:

- `nextjs-app`: the production build served via `next start`
- `postgres`: task database seeded through Prisma migrations
- `postgres-exporter`: Prometheus exporter for the DB
- `node_exporter`: host metrics, mirroring the Express example

From this folder run:

```bash
docker compose up --build
```

The app exposes port `3000`, while Postgres listens on `5433` by default (configurable through environment variables at the top of the compose file).

## Useful scripts

- `npm run prisma:generate` – regenerate the Prisma Client
- `npm run prisma:migrate:dev` – create a new migration in development
- `npm run prisma:migrate:deploy` – apply migrations in production (used in Docker)
- `npm run prisma:studio` – open Prisma Studio for inspecting data

Happy hacking!
