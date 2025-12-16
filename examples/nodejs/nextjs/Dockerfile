# Build stage
FROM node:22-alpine AS builder
WORKDIR /app

ARG DATABASE_URL=postgresql://userdemo:userdemo@postgres:5432/userdemo?schema=public
ENV DATABASE_URL=$DATABASE_URL
ENV NEXT_TELEMETRY_DISABLED=1

COPY package*.json ./
RUN npm ci

COPY prisma ./prisma
RUN npm run prisma:generate

COPY . .
RUN npm run build

# Production runtime
FROM node:22-alpine AS runner
WORKDIR /app
ARG DATABASE_URL=postgresql://userdemo:userdemo@postgres:5432/userdemo?schema=public
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV DATABASE_URL=$DATABASE_URL

COPY package*.json ./
COPY --from=builder /app/node_modules ./node_modules

COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/next.config.ts ./next.config.ts
COPY --from=builder /app/instrumentation.ts ./instrumentation.ts
COPY --from=builder /app/otel.ts ./otel.ts

EXPOSE 3000

CMD ["npm", "run", "start"]
