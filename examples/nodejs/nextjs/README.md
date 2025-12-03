# Next.js Task Manager with LGTM Observability Stack

A full-stack Next.js application with complete observability using the **LGTM Stack** (Loki, Grafana, Tempo, Mimir/Prometheus) and OpenTelemetry.

## 🏗️ Architecture

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────┐
│  Next.js App    │────▶│  OpenTelemetry       │────▶│   Tempo     │ (Traces)
│                 │     │  Collector (Alloy)   │     └─────────────┘
│  - API Routes   │     │                      │     ┌─────────────┐
│  - React UI     │     │  - Receives OTLP     │────▶│   Loki      │ (Logs)
│  - Traces       │     │  - Routes telemetry  │     └─────────────┘
│  - Metrics      │     │  - Transforms data   │     ┌─────────────┐
│  - Logs         │     └──────────────────────┘────▶│ Mimir       │ (Metrics)
└─────────────────┘                                  └─────────────┘
                                                           │
                                                           ▼
                                                     ┌─────────────┐
                                                     │ Pyroscope   │ (Profiling)
                                                     └─────────────┘
                                                           │
                                                           ▼
                                                     ┌─────────────┐
                                                     │   Grafana   │ (Visualization)
                                                     └─────────────┘
```

## ✨ Features

### Task Management
- ✅ Create, Read, Update, Delete (CRUD) tasks
- 📅 Task scheduling with dates
- 🎯 Task status tracking (Pending, In Progress, Done)
- 💅 Modern, responsive UI with Tailwind CSS

### Observability
- 📊 **Traces** - Automatic HTTP request tracing with Tempo
- 📈 **Metrics** - Request rate, latency, and custom metrics with Mimir
- 📝 **Logs** - Structured logging with trace correlation via Loki
- 🔥 **Profiling** - CPU and memory profiling with Pyroscope
- 🔗 **Correlation** - Logs automatically linked to traces

## 🚀 Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment Variables

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

### 3. Start the Observability Stack

```bash
docker-compose up -d grafana tempo loki mimir alloy pyroscope postgres
```

### 4. Setup Database

```bash
npm run prisma:generate
npm run prisma:migrate
```

### 5. Run the Application

```bash
npm run dev
```

### 6. Or Run Everything with Docker

```bash
docker-compose up -d
```

## 📱 Access the Services

| Service         | URL                          | Credentials   |
|-----------------|------------------------------|---------------|
| Next.js App     | http://localhost:3000        | -             |
| Grafana         | http://localhost:3030        | admin / admin |
| Pyroscope       | http://localhost:4040        | -             |

## 📊 What's Included

- ✅ Automatic HTTP request tracing
- ✅ Database query tracing (Prisma)
- ✅ Structured JSON logging with Pino
- ✅ Log correlation with trace IDs
- ✅ CPU and memory profiling with Pyroscope
- ✅ Modern, responsive UI with Tailwind CSS

## 🔧 Configuration

### Required Files for Your Own Project

Copy these files to add LGTM observability:

1. **`instrumentation.ts`** - OpenTelemetry and Pyroscope setup
2. **`src/lib/logger.ts`** - Pino logger configuration
3. **`observability/`** - LGTM stack configuration files
4. **`docker-compose.yaml`** - Docker services orchestration

### Adding Logging to Your Code

```typescript
import { logger } from '@/lib/logger';

export async function GET() {
  logger.info('Fetching data');
  logger.info({ count: data.length }, 'Data retrieved');
}
```

## 📚 Resources

- [Next.js Documentation](https://nextjs.org/docs)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Grafana LGTM Stack](https://grafana.com/oss/lgtm-stack/)
- [Pino Logger](https://getpino.io/)

---

Built with ❤️ using Next.js 15, React 19, OpenTelemetry, and the LGTM Stack