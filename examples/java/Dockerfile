# Multi-stage Dockerfile for Spring Boot Application with OpenTelemetry

# Stage 1: Build the application
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# Copy pom.xml first for dependency caching
COPY pom.xml ./

# Generate Maven wrapper files automatically
RUN mvn wrapper:wrapper

# Download dependencies (cached layer)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application (skip tests for faster builds)
RUN ./mvnw clean package -DskipTests

# Stage 2: Download OpenTelemetry Java Agent
FROM alpine:latest AS otel-agent
WORKDIR /otel
RUN apk add --no-cache curl && \
    curl -L -o opentelemetry-javaagent.jar \
    https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar

# Stage 3: Runtime image
FROM eclipse-temurin:17-jre
LABEL maintainer="userdemo-agent-micrometer"
LABEL description="Userdemo Spring Boot Application with OpenTelemetry Java Agent, Micrometer, and Prometheus"

# Create non-root user for security (Debian-based commands)
RUN groupadd -r spring && useradd -r -g spring spring

# Set working directory
WORKDIR /app

# Copy the built JAR from build stage
COPY --from=build /app/target/userdemo-agent-micrometer-0.0.1-SNAPSHOT.jar app.jar

# Copy OpenTelemetry agent from otel-agent stage
COPY --from=otel-agent /otel/opentelemetry-javaagent.jar otel-javaagent.jar

# Change ownership to non-root user
RUN chown -R spring:spring /app

# Switch to non-root user
USER spring:spring

# Expose application port
EXPOSE 8081

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8081/actuator/health || exit 1

# Environment variables for OpenTelemetry
ENV OTEL_SERVICE_NAME=userdemo-agent-micrometer
ENV OTEL_TRACES_EXPORTER=otlp
ENV OTEL_METRICS_EXPORTER=otlp
ENV OTEL_LOGS_EXPORTER=otlp
ENV OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
ENV OTEL_INSTRUMENTATION_COMMON_DEFAULT_ENABLED=true
ENV OTEL_INSTRUMENTATION_JDBC_ENABLED=true
ENV OTEL_INSTRUMENTATION_SPRING_WEB_ENABLED=true

# Enable MDC (Mapped Diagnostic Context) instrumentation for trace correlation in logs
ENV OTEL_INSTRUMENTATION_COMMON_MDC_ENABLED=true
ENV OTEL_INSTRUMENTATION_LOGBACK_MDC_ADD_BAGGAGE=true

# JVM Options for container environment
ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -Djava.security.egd=file:/dev/./urandom"

# Run application with OpenTelemetry agent
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -javaagent:otel-javaagent.jar -jar app.jar"]
