# =======================================
# Builder Stage - Build Next.js standalone
# =======================================
FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma/
COPY prisma.config.ts ./

RUN npm ci --legacy-peer-deps

# Prisma config in this repo expects DB_URL; provide a dummy value for build-time generation.
ENV DB_URL="postgresql://dummy:dummy@localhost:5432/dummy"

COPY . .

RUN npm run prisma:generate
RUN npm run build


# ================================
# Dependencies Stage - production
# ================================
FROM node:22-alpine AS deps

WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma/
COPY prisma.config.ts ./

# Install production deps (includes dotenv, @prisma/client, etc.)
RUN npm ci --omit=dev --legacy-peer-deps

# Install prisma CLI for runtime migrations
RUN npm install prisma --no-save --legacy-peer-deps


# =================================
# Runtime Stage - minimal production
# =================================
FROM node:22-alpine AS production

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

# Standalone output includes the minimal server. We'll also bring in a full
# node_modules from the deps stage so Prisma CLI can run at startup.
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

COPY --from=deps /app/node_modules ./node_modules

# Prisma migrations need schema + migrations at runtime.
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/prisma.config.ts ./prisma.config.ts

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 && \
    chown -R nextjs:nodejs /app

USER nextjs

EXPOSE 3000

# Run migrations then start Next.js standalone server.
# Note: prisma CLI must exist in runtime deps; it's currently installed via package.json.
CMD ["sh", "-c", "npx prisma migrate deploy --schema=./prisma/schema.prisma && node server.js"]
