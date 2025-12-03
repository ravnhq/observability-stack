# Use Node.js 20 LTS
FROM node:20-alpine AS base

# Set working directory
WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl

# Copy package files
COPY package*.json ./
COPY tsconfig*.json ./

# Development stage
FROM base AS development
RUN npm ci
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]

# Build stage
FROM base AS build
RUN npm ci --only=production && npm cache clean --force
COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine AS production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S express -u 1001

# Install curl for health checks
RUN apk add --no-cache curl

WORKDIR /app

# Copy built application
COPY --from=build --chown=express:nodejs /app/dist ./dist
COPY --from=build --chown=express:nodejs /app/node_modules ./node_modules
COPY --from=build --chown=express:nodejs /app/package*.json ./
COPY --from=build --chown=express:nodejs /app/prisma ./prisma

# Switch to non-root user
USER express

# Health check (update to match your health endpoint)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000

# 🔧 Fixed: Use the correct entry point from package.json
CMD ["node", "dist/server.js"]