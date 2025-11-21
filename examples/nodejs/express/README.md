# Minimal Metrics API

A clean, minimal Express + TypeScript + PostgreSQL + Prisma setup for metrics collection, ready to be plugged into Grafana/Tempo/Loki/Mimir observability stack.

## 🚀 Quick Start

### 1. Install Dependencies
```bash
cd minimal-metrics-api
npm install
```

### 2. Setup Database
```bash
# Start PostgreSQL (example with Docker)
docker run --name postgres-metrics \
  -e POSTGRES_USER=user \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB=metrics_demo \
  -p 5432:5432 \
  -d postgres:15

# Update .env with your database URL
# DATABASE_URL="postgresql://user:password@localhost:5432/metrics_demo?schema=public"
```

### 3. Initialize Prisma
```bash
npx prisma generate
npx prisma migrate dev --name init_tasks
```

### 4. Start Development Server
```bash
npm run dev
```

## 📁 Project Structure

```
minimal-metrics-api/
├─ prisma/
│  └─ schema.prisma          # Database schema
├─ src/
│  ├─ config/
│  │  └─ db.ts              # Prisma client
│  ├─ tasks/
│  │  ├─ task.types.ts      # Core interfaces/types
│  │  ├─ task.dto.ts        # Data Transfer Objects
│  │  ├─ task.service.ts    # Business logic
│  │  ├─ task.controller.ts # Express handlers
│  │  └─ task.routes.ts     # Route definitions
│  ├─ app.ts                # Express app setup
│  └─ server.ts             # Server entrypoint
├─ .env                     # Environment variables
├─ package.json
├─ tsconfig.json
└─ .gitignore
```

## 📡 API Endpoints

| Method | Endpoint | Description | Example |
|--------|----------|-------------|---------|
| `GET` | `/health` | Health check | `200 { "status": "ok" }` |
| `GET` | `/tasks` | List all tasks | Returns array of tasks |
| `GET` | `/tasks/:id` | Get task by ID | Returns single task |
| `POST` | `/tasks` | Create new task | See [Create Task](#create-task) |
| `PUT` | `/tasks/:id` | Update task | See [Update Task](#update-task) |
| `DELETE` | `/tasks/:id` | Delete task | `204 No Content` |

### Create Task
```bash
POST /tasks
Content-Type: application/json

{
  "name": "Implement metrics",
  "description": "Add tracing and logs",
  "date": "2025-11-21T12:00:00.000Z",
  "status": "PENDING"
}
```

### Update Task
```bash
PUT /tasks/1
Content-Type: application/json

{
  "name": "Updated task name",
  "status": "IN_PROGRESS"
}
```

## 🗄️ Database Schema

### Task Model
```prisma
model Task {
  id          Int        @id @default(autoincrement())
  name        String     // Task name
  description String?    // Optional description
  date        DateTime   // Due date or task date
  status      TaskStatus @default(PENDING)
  createdAt   DateTime   @default(now())
  updatedAt   DateTime   @updatedAt
}

enum TaskStatus {
  PENDING
  IN_PROGRESS
  DONE
}
```

## 🛠️ Available Scripts

| Script | Description |
|--------|-------------|
| `npm run dev` | Start development server with hot reload |
| `npm run build` | Build TypeScript to JavaScript |
| `npm start` | Start production server |
| `npm run prisma:generate` | Generate Prisma client |
| `npm run prisma:migrate` | Run database migrations |

## 🔧 Configuration

### Environment Variables (.env)
```bash
DATABASE_URL="postgresql://user:password@localhost:5432/metrics_demo?schema=public"
PORT=3000
```

### TypeScript Configuration
- **Target**: ES2020
- **Module**: CommonJS
- **Strict mode**: Enabled
- **Output**: `./dist`

## 📊 Data Flow

1. **Request** → **Routes** → **Controller** → **Service** → **Database**
2. **Database** → **Service** → **Controller** → **Response**

### Architecture Layers

- **Routes**: Express route definitions and middleware
- **Controllers**: Thin HTTP handlers, validation, response formatting
- **Services**: Business logic, data transformation, database interactions
- **DTOs**: Data Transfer Objects for API contracts
- **Types**: Core domain interfaces and types

## 🔗 Ready for Observability

This minimal setup is designed to be easily extended with:

- **OpenTelemetry** instrumentation
- **Grafana** dashboards
- **Tempo** distributed tracing
- **Loki** log aggregation
- **Mimir** metrics collection

The clean architecture makes it simple to add observability hooks at each layer:
- HTTP middleware for request/response metrics
- Service layer for business metrics
- Database layer for query performance
- Error handling for failure tracking

## 🚀 Next Steps

1. **Add OpenTelemetry**: Instrument the Express app for tracing
2. **Add Metrics**: Custom business metrics and Prometheus endpoints
3. **Add Logging**: Structured logging with correlation IDs
4. **Add Validation**: Runtime validation with Zod or class-validator
5. **Add Tests**: Unit and integration tests

---

**Perfect foundation for production-ready metrics collection! 🎯**