# =================================
# Builder Stage - Build Application
# =================================
FROM node:22-alpine AS builder

WORKDIR /app

# Copy package files and Prisma schema
COPY package*.json ./
COPY prisma ./prisma/
COPY prisma.config.ts ./

# Install ALL dependencies (including dev) for building
RUN npm ci --legacy-peer-deps

# Set dummy DB_URL for Prisma generation (schema validation only)
ENV DB_URL="postgresql://dummy:dummy@localhost:5432/dummy"

# Generate Prisma Client (creates node_modules/@prisma/client)
RUN npx prisma generate

# Copy source code
COPY . .

# Build the Express application (compiles TypeScript to JavaScript)
RUN npm run build

# =================================
# Dependencies Stage - Production Dependencies
# =================================
FROM node:22-alpine AS deps

WORKDIR /app

# Copy package files and Prisma schema
COPY package*.json ./
COPY prisma ./prisma/
COPY prisma.config.ts ./

# Install production dependencies
RUN npm ci --omit=dev --legacy-peer-deps

# Install prisma CLI for migrations (needed at runtime)
RUN npm install prisma --save

# Set dummy DB_URL for Prisma generation
ENV DB_URL="postgresql://dummy:dummy@localhost:5432/dummy"

# Generate Prisma Client in production node_modules
RUN npx prisma generate

# =================================
# Production Stage - Final Runtime Image
# =================================
FROM node:22-alpine AS production

WORKDIR /app

# Copy package.json for metadata
COPY package*.json ./

# Copy production node_modules (includes @prisma/client and prisma CLI)
COPY --from=deps /app/node_modules ./node_modules

# Copy Prisma files (needed for migrations at runtime)
COPY prisma ./prisma/
COPY prisma.config.ts ./

# Copy compiled application from builder
COPY --from=builder /app/dist ./dist

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S expressjs -u 1001 && \
    chown -R expressjs:nodejs /app

USER expressjs

# Expose application port
EXPOSE 3000

# Run migrations and start the application
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/server.js"]
