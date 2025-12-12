# Adding OpenTelemetry Observability to Spring Boot

How to add **production-ready observability** to Spring Boot applications using the OpenTelemetry Java Agent, Micrometer with Prometheus, and the Grafana LGTM stack.

## Table of Contents
- [How to Setup the LGTM Stack](#how-to-setup-the-lgtm-stack)
- [How to Instrument Your Spring Boot Project](#how-to-instrument-your-spring-boot-project)
- [How to Implement Custom Metrics](#how-to-implement-custom-metrics)
- [Quick Start Example Guide](#quick-start-example-guide)
- [Key Configuration Files Reference](#key-configuration-files-reference)
- [Troubleshooting](#troubleshooting)
- [Resources & Further Reading](#resources--further-reading)

## How to Setup the LGTM Stack

The LGTM observability stack (Loki, Grafana, Tempo, Mimir) can be installed with a single command using the provided installation script. The script automatically downloads all necessary configuration files and sets up the complete observability infrastructure.

### Prerequisites

The installation script validates the following dependencies automatically:
- **Docker**: Container runtime
- **Docker Compose**: Service orchestration
- **curl**: For downloading files

If any dependency is missing, the script will provide installation instructions.

### Installation Scenarios

#### Fresh Installation (Default)

Install the stack from the master branch to a new `./observability/` directory:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/master/install.sh)
```

**What this does:**
- Downloads essential files to `./observability/` directory
- Creates `.env` file from template
- Generates a secure Grafana admin password automatically

**Startup time:** Initial startup typically takes 2-3 minutes as Docker builds images and initializes services.

#### Branch-Specific Installation

Install from a specific Git branch (e.g., to test new features or use a development version):

```bash
bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/java/install.sh) --branch java
```

**Note:** When using a different branch, ensure the URL path matches the branch name in both the download URL and the `--branch` parameter.

### Post-Installation Configuration

After installation, review and modify `./observability/.env` to adapt the stack to your deployment infrastructure:

#### Storage Configuration

```bash
# Storage backend type
STORAGE_TYPE=filesystem  # Options: filesystem, s3, gcs
```

- **filesystem**: Data stored locally (default, good for development)
- **s3**: AWS S3 buckets (recommended for production)
- **gcs**: Google Cloud Storage (alternative for GCP deployments)

#### Cloud Storage Credentials (if using S3)

```bash
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1

# S3 bucket names
LOKI_S3_BUCKET=loki-logs
TEMPO_S3_BUCKET=tempo-traces
MIMIR_S3_BUCKET=mimir-metrics
```

#### Cloud Storage Credentials (if using GCS)

```bash
GCS_BUCKET_NAME=your-bucket-name
GCS_SERVICE_ACCOUNT_KEY=/path/to/service-account-key.json
```

#### Port Configuration

Adjust ports if defaults conflict with existing services:

```bash
GRAFANA_PORT=3030        # Default Grafana UI
ALLOY_OTLP_GRPC_PORT=4317  # OTLP gRPC endpoint
ALLOY_OTLP_HTTP_PORT=4318  # OTLP HTTP endpoint
ALLOY_UI_PORT=12345        # Alloy configuration UI
```

#### Data Retention Periods

Configure how long telemetry data is stored:

```bash
LOKI_RETENTION_PERIOD=168h    # 7 days (logs)
TEMPO_RETENTION_PERIOD=336h   # 14 days (traces)
MIMIR_RETENTION_PERIOD=8760h  # 365 days (metrics)
```

#### Scrape Targets (for distributed deployments)

Configure external endpoints for Prometheus scraping:

```bash
# Application metrics endpoint
SCRAPE_APP_TARGET=host.docker.internal:8080
SCRAPE_APP_METRICS_PATH=/actuator/prometheus

# PostgreSQL exporter metrics
SCRAPE_POSTGRES_TARGET=host.docker.internal:9187
SCRAPE_POSTGRES_METRICS_PATH=/metrics

# Node exporter metrics
SCRAPE_NODE_EXPORTER_TARGET=host.docker.internal:9100
SCRAPE_NODE_EXPORTER_METRICS_PATH=/metrics
```

For distributed deployments where applications run on different hosts, replace `host.docker.internal` with the actual hostname or IP address.

### Access Points

After the stack is running, access these services:

| Service | URL | Credentials | Purpose |
|---------|-----|-------------|---------|
| **Grafana** | http://localhost:3030 | admin / [generated-password]* | Visualization dashboards |
| **Alloy UI** | http://localhost:12345 | None | Telemetry pipeline status |
| **OTLP gRPC** | localhost:4317 | None | Application trace/metric submission |
| **OTLP HTTP** | localhost:4318 | None | Application trace/metric submission |

**\*Note:** The Grafana password is displayed in the installation output and saved in `./observability/.env`

## How to Instrument Your Spring Boot Project

Spring Boot applications can be instrumented with OpenTelemetry using two approaches: an automated setup script (recommended) or manual implementation. The automated script handles both new and existing projects, while the manual approach gives you full control over each step.

### Approach 1: Automated Setup Script (Recommended)

The setup script automates the complete instrumentation process, including downloading the OpenTelemetry Java Agent, configuring Docker, and setting up logging with trace correlation.

#### Prerequisites

**Spring Boot CLI is ONLY required if:**
- You want to create a **new project from scratch** using the script
- You will answer "Yes" when the script asks "Are you starting a new project?"
- Installation guide: https://docs.spring.io/spring-boot/installing.html#getting-started.installing.cli
- Verify installation: `spring --version`

**Spring Boot CLI is NOT required if:**
- You have an **existing project** (created from Spring Initializr, IDE, or manually)
- You will answer "No" when asked about creating a new project
- The script will work with any existing Maven-based Spring Boot project

#### Basic Usage

**From master branch:**
```bash
bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/master/setup/java/setup-otel.sh)
```

**From specific branch:**
```bash
bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/java/setup/java/setup-otel.sh) --branch java
```

**Note:** Gradle projects are not currently supported by the automated script. Use manual implementation for Gradle-based projects.

**Supported Java versions:** 17, 21, 25

**Files copied:**

> **⚠️ Important for Existing Projects:**
>
> The setup script will copy and potentially **overwrite** key configuration files including:
> - `Dockerfile`
> - `docker-compose.yaml`
> - `src/main/resources/application.properties`
> - `src/main/resources/logback-spring.xml`
> - `.env`
>
> **Use the automated script only if:**
> - ✅ Creating a brand new project from scratch
> - ✅ Working with an early-stage project created via Spring Initializr or IDE wizard
> - ✅ The project has minimal custom configuration that can be safely overwritten
>
> **Use manual implementation instead if:**
> - ❌ Your project has established configurations you want to preserve
> - ❌ You have custom Docker setups, logging configurations, or environment files
> - ❌ You need fine-grained control over what changes are made
> - ❌ Your project is in active development with team-specific conventions
>
> See [Approach 2: Manual Implementation](#approach-2-manual-implementation-reference) for step-by-step manual instrumentation that gives you full control.


| File | Location | Purpose |
|------|----------|---------|
| `Dockerfile` | `./Dockerfile` | Multi-stage build with OTel agent |
| `docker-compose.yaml` | `./docker-compose.yaml` | Application services orchestration |
| `application.properties` | `./src/main/resources/application.properties` | Spring Boot configuration |
| `logback-spring.xml` | `./src/main/resources/logback-spring.xml` | Logging with trace IDs |

**Key environment variables configured:**

```bash
# OpenTelemetry Agent Configuration
OTEL_SERVICE_NAME=your-service-name
OTEL_SERVICE_VERSION=0.0.1
OTEL_DEPLOYMENT_ENVIRONMENT=development
OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318

# MDC Instrumentation (for trace correlation in logs)
OTEL_INSTRUMENTATION_COMMON_MDC_ENABLED=true
OTEL_INSTRUMENTATION_LOGBACK_MDC_ADD_BAGGAGE=true
```

**PostgreSQL configuration** (if selected):
```bash
# Database Configuration
POSTGRES_DB=mydatabase
POSTGRES_USER=admin
POSTGRES_PASSWORD=secret
DB_URL=jdbc:postgresql://postgres:5432/mydatabase
```

#### What the Script Configures

##### Dockerfile (Multi-stage Build)

The generated Dockerfile includes:

**Stage 1: Build Stage**
- Uses Maven to build the application (Gradle not currently supported)
- Caches dependencies for faster subsequent builds

**Stage 2: OpenTelemetry Agent Download**
- Downloads latest OpenTelemetry Java Agent from GitHub releases
- URL: https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar

**Stage 3: Runtime Stage**
- Uses minimal Eclipse Temurin JRE image
- Copies built JAR and OTel agent
- Runs as non-root user for security
- ENTRYPOINT: `java $JAVA_OPTS -javaagent:otel-javaagent.jar -jar app.jar`
- Includes health check for container orchestration

##### application.properties

Configures Spring Boot Actuator and metrics:

```properties
spring.application.name=${SPRING_APPLICATION_NAME:demo}
server.port=${SERVER_PORT:8080}

# Actuator endpoints
management.endpoints.web.exposure.include=health,info,prometheus,metrics
management.endpoint.health.show-details=always
```

**Key endpoints exposed:**
- `/actuator/health` - Application health status
- `/actuator/prometheus` - Prometheus metrics (scraped by Alloy)
- `/actuator/metrics` - Micrometer metrics

##### logback-spring.xml

Configures logging with OpenTelemetry trace correlation:

```xml
<pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} [traceid=%X{trace_id:-}, spanid=%X{span_id:-}] - %msg%n</pattern>
```

**What this does:**
- Includes `trace_id` and `span_id` in every log entry
- Enables linking logs to distributed traces in Grafana
- MDC (Mapped Diagnostic Context) values injected automatically by OTel agent
- Logs show: `[traceid=abc123, spanid=def456]` for active spans

##### docker-compose.yaml

Orchestrates application and optional services:

**Application service:**
- Builds from Dockerfile
- Exposes application port (default 8080)
- Passes OpenTelemetry environment variables
- Connects to observability stack via OTLP endpoint

**PostgreSQL service** (if selected):
- PostgreSQL 16 database
- Health checks for reliable startup
- Persistent volume for data

**postgres-exporter service** (if selected):
- Exposes PostgreSQL metrics at port 9187
- Scraped by Alloy for database observability

##### .env Configuration

Environment variables for application and instrumentation:

**Service identification:**
```bash
OTEL_SERVICE_NAME=your-service-name
OTEL_SERVICE_VERSION=0.0.1
OTEL_DEPLOYMENT_ENVIRONMENT=development
```

**OTLP endpoint:**
```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318
```

**Trace correlation in logs:**
```bash
OTEL_INSTRUMENTATION_COMMON_MDC_ENABLED=true
OTEL_INSTRUMENTATION_LOGBACK_MDC_ADD_BAGGAGE=true
```

#### After Setup Complete

**Next steps:**
1. Review and update `.env` with your service name and configuration
2. Build and start application: `docker-compose up -d --build`
3. Access application: http://localhost:8080
4. View metrics: http://localhost:8080/actuator/prometheus
5. Check Grafana for traces: http://localhost:3030

**Connecting to LGTM Stack:**
- If LGTM stack is running on the same host, the default OTLP endpoint works: `http://host.docker.internal:4318`
- For distributed deployments, update `OTEL_EXPORTER_OTLP_ENDPOINT` in `.env` to point to your Alloy instance

### Approach 2: Manual Implementation (Reference)

This manual approach gives you complete control over the instrumentation process and is the **recommended approach** for:
- Established projects with existing configurations
- Gradle-based projects (not supported by automated script)
- Projects requiring custom Docker, logging, or environment setups
- Teams with specific conventions and standards

**Supported build tools:** Maven and Gradle both work with manual implementation.

For users who prefer manual control or want to understand each step, follow this checklist to implement instrumentation yourself.

### Checklist: Implementing in Existing Apps

#### 1. Add Dependencies

Add the Spring Boot Actuator and Micrometer Prometheus Registry dependencies to your project.

**Note:** While the automated setup script only supports Maven, you can manually implement instrumentation for Gradle projects by following these steps.

**Maven** (`pom.xml`):
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
<dependency>
	<groupId>io.micrometer</groupId>
	<artifactId>micrometer-tracing-bridge-otel</artifactId>
</dependency>
```

**Gradle** (`build.gradle`):
```groovy
implementation 'org.springframework.boot:spring-boot-starter-actuator'
implementation 'io.micrometer:micrometer-registry-prometheus'
implementation 'io.micrometer:micrometer-tracing-bridge-otel'
```

#### 2. Update application.properties

Add these lines:
```properties
management.endpoints.web.exposure.include=health,info,prometheus,metrics
management.endpoint.health.show-details=always
```

#### 3. Configure Logging

Configure your logging framework to include trace correlation IDs (`trace_id` and `span_id`) in your log patterns. This enables linking logs to traces in Grafana.

For **Logback** (default in Spring Boot), create or update `logback-spring.xml`:
```xml
<pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} [traceid=%X{trace_id:-}, spanid=%X{span_id:-}] - %msg%n</pattern>
```

#### 4. Update Dockerfile

Add OTel agent download and attachment:
```dockerfile
# Download agent stage
FROM eclipse-temurin:17-jre AS agent
RUN apt-get update && apt-get install -y wget && \
    wget -O /otel-javaagent.jar \
    https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar

# Runtime stage
FROM eclipse-temurin:17-jre
COPY --from=agent /otel-javaagent.jar otel-javaagent.jar
COPY target/*.jar app.jar
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -javaagent:otel-javaagent.jar -jar app.jar"]
```

#### 5. Add Environment Variables

In your docker-compose.yaml or Kubernetes deployment:
```yaml
environment:
  # OpenTelemetry Agent Configuration
  OTEL_SERVICE_NAME: ${OTEL_SERVICE_NAME:-your-service-name}
  OTEL_SERVICE_VERSION: ${OTEL_SERVICE_VERSION:-0.0.1}
  OTEL_DEPLOYMENT_ENVIRONMENT: ${OTEL_DEPLOYMENT_ENVIRONMENT:-development}
  OTEL_EXPORTER_OTLP_ENDPOINT: ${OTEL_EXPORTER_OTLP_ENDPOINT:-http://alloy:4318}
  OTEL_RESOURCE_ATTRIBUTES: service.name=${OTEL_SERVICE_NAME:-your-service-name},service.version=${OTEL_SERVICE_VERSION:-0.0.1},deployment.environment=${OTEL_DEPLOYMENT_ENVIRONMENT:-development}
  # MDC Instrumentation for trace correlation in logs
  OTEL_INSTRUMENTATION_COMMON_MDC_ENABLED: ${OTEL_INSTRUMENTATION_COMMON_MDC_ENABLED:-true}
  OTEL_INSTRUMENTATION_LOGBACK_MDC_ADD_BAGGAGE: ${OTEL_INSTRUMENTATION_LOGBACK_MDC_ADD_BAGGAGE:-true}
```

#### 6. Set Up Grafana Alloy

- Update the env variables as needed in observability/.env
- Update endpoints to match your infrastructure
- Adjust scrape intervals if needed

```
// Scrape job for application metrics (configurable)
prometheus.scrape "application" {
  targets = [
    {
      "__address__" = env("SCRAPE_APP_TARGET"),
      "job"         = env("SCRAPE_APP_JOB"),
      "environment" = env("ENVIRONMENT"),
      "service"     = env("SCRAPE_APP_JOB"),
    },
  ]

  forward_to      = [prometheus.remote_write.mimir.receiver]
  scrape_interval = "15s"
  scrape_timeout  = "10s"
  metrics_path    = env("SCRAPE_APP_METRICS_PATH")
}
```

#### 7. Deploy LGTM Stack

Deploy Tempo, Mimir, Loki, and Grafana:
- Use docker-compose.yaml as reference
- Or deploy to Kubernetes with Helm charts

### Production Considerations

**Security:**
- ✅ Enable authentication for Grafana (remove anonymous access)
- ✅ Use TLS for OTLP endpoints
- ✅ Add authentication to Alloy → backends (basic auth or API keys)
- ✅ Secure Prometheus endpoint (require authentication)

**Performance:**
- ✅ Adjust Alloy batch sizes based on traffic volume
- ✅ Configure retention policies for Tempo, Mimir, Loki
- ✅ Set resource limits on all containers
- ✅ Use sampling for high-traffic applications (reduce trace volume)

**Scalability:**
- ✅ Run multiple Alloy instances with load balancing
- ✅ Deploy LGTM backends in distributed mode (not monolithic)
- ✅ Use object storage (S3, GCS) for long-term trace/metric storage
- ✅ Implement alerting rules in Mimir

**Monitoring the Monitoring:**
- ✅ Monitor Alloy health and throughput
- ✅ Set up alerts for telemetry pipeline failures
- ✅ Track metrics ingestion rates and storage usage

[Back to Table of Contents](#table-of-contents)

---

## How to Implement Custom Metrics

### Why Custom Metrics?

While the default metrics from Micrometer and the OpenTelemetry agent provide excellent infrastructure and HTTP request metrics, **custom metrics let you track business-specific events and application domain logic**.

**Default metrics tell you:**
- JVM memory usage
- HTTP request rates and latencies
- Database connection pool utilization
- Thread counts and garbage collection

**Custom metrics tell you:**
- Users created in the last hour
- Orders processed by region
- Payment transactions by method
- Current inventory levels
- Active sessions by company

**When to add custom metrics:**
- ✅ Track business KPIs (conversion rates, revenue, user growth)
- ✅ Monitor domain-specific workflows (checkout completion, signup funnel)
- ✅ Measure application-specific events (cache hits, batch job processing)
- ✅ Create business dashboards for non-technical stakeholders
- ✅ Set up alerts on business thresholds (low inventory, high error rates)

### Trade-offs and Considerations

Unlike default metrics that work automatically, custom metrics require code changes and ongoing maintenance.

| Aspect | Default Metrics | Custom Metrics |
|--------|----------------|----------------|
| **Code Required** | None (automatic) | Yes (explicit instrumentation) |
| **Maintenance** | Maintained by framework | You maintain the code |
| **Scope** | Infrastructure & HTTP | Business logic & domain events |
| **Setup Time** | Immediate | Requires development |
| **Cardinality Risk** | Low (predefined tags) | High (if misused with unique IDs) |
| **Business Value** | System health | Business insights |

**Key risks to avoid:**

⚠️ **High cardinality tags**: Never use user IDs, session IDs, or timestamps as tags
```java
// BAD - Creates millions of unique metric combinations
Counter.builder("orders.total")
       .tag("user.id", userId)        // ❌ Unique per user
       .tag("timestamp", timestamp)   // ❌ Unique per second
       .register(meterRegistry);

// GOOD - Uses categorical tags
Counter.builder("orders.total")
       .tag("region", "us-east")      // ✅ Limited values
       .tag("payment.method", "card") // ✅ Limited values
       .register(meterRegistry);
```

⚠️ **Metric explosion**: Too many unique metrics can overwhelm your monitoring system

⚠️ **Performance overhead**: Metrics collection is fast, but millions of metrics per second can impact performance

✅ **Benefits when done right**: Business dashboards, better alerting, domain-specific insights

### Counter vs Gauge: Choosing the Right Metric Type

Micrometer provides several metric types, but **Counter** and **Gauge** are the most commonly used for custom metrics.

#### Counter: Tracking Events Over Time

**Counters** are monotonically increasing values that only go up (never decrease). Use counters to track events that accumulate.

**Characteristics:**
- Always increases
- Resets to 0 on application restart
- Prometheus convention: metric name ends with `_total`
- Query with `rate()` or `increase()` to see growth over time

**When to use:**
- ✅ User registrations
- ✅ API requests processed
- ✅ Orders completed
- ✅ Emails sent
- ✅ Errors encountered

**Example from this project** (`UserMetricsService.java`):

```java
private void incrementCreateCounter(String companyName, String countryName) {
    Counter.builder("users.created.total")
           .tag("company.name", companyName)
           .tag("country.name", countryName)
           .description("Total number of users created")
           .register(meterRegistry)
           .increment();
}
```

**What you get:**
- Metric name: `users_created_total`
- Tags: `company_name`, `country_name`
- Value increases by 1 each time a user is created

**Query in Grafana:**
```promql
# Users created per second in the last 5 minutes
rate(users_created_total{company_name="Acme Corporation"}[5m])

# Total users created in last hour
increase(users_created_total[1h])
```

#### Gauge: Tracking Current State

**Gauges** represent point-in-time measurements that can go up or down. Use gauges to track current values.

**Characteristics:**
- Can increase or decrease
- Represents "right now" value
- No `_total` suffix
- Query directly to see current value

**When to use:**
- ✅ Current user count
- ✅ Active sessions
- ✅ Queue size
- ✅ Inventory levels
- ✅ Temperature/sensor readings

**Example from this project** (`UserMetricsService.java`):

```java
private void registerCompanyGauge(String companyName, String countryName, AtomicInteger counter) {
    String gaugeKey = "company:" + companyName;

    // Prevent duplicate registration
    if (registeredGauges.add(gaugeKey)) {
        Gauge.builder("users.count.by.company", counter, AtomicInteger::get)
             .tag("company.name", companyName)
             .tag("country.name", countryName)
             .description("Number of users in company")
             .register(meterRegistry);

        LOGGER.info("Registered gauge for company='{}', country='{}'", companyName, countryName);
    }
}
```

**Key pattern for gauges:**
- Use `AtomicInteger` (or `AtomicDouble`) for thread-safe updates
- Register gauge once, update the underlying value
- Gauge reads from the `AtomicInteger` automatically

**Query in Grafana:**
```promql
# Current user count by company
users_count_by_company{company_name="Acme Corporation"}

# Total users across all companies
sum(users_count_by_company)
```

#### Quick Decision Guide

| Scenario | Metric Type | Example |
|----------|-------------|---------|
| Track events happening | Counter | `orders.completed.total` |
| Track current state | Gauge | `active.sessions.count` |
| Something always increases | Counter | `api.requests.total` |
| Something goes up and down | Gauge | `queue.size` |
| Need rate/velocity | Counter | `users.created.total` → `rate()` |
| Need current value | Gauge | `inventory.level` |

### Metric Naming Conventions

Micrometer uses **dot notation** for metric names, which automatically converts to Prometheus format (underscores).

**Pattern:** `<domain>.<entity>.<measurement>[.unit]`

**Examples from this project:**

| Micrometer Name | Prometheus Name | Description |
|----------------|-----------------|-------------|
| `users.created.total` | `users_created_total` | Counter of users created |
| `users.deleted.total` | `users_deleted_total` | Counter of users deleted |
| `users.count.by.company` | `users_count_by_company` | Gauge of current users per company |
| `users.count.by.country` | `users_count_by_country` | Gauge of current users per country |

**Naming best practices:**

✅ **Use lowercase with dots**: `users.created.total`
✅ **Be descriptive but concise**: `orders.completed.total` not `o.c.t`
✅ **End counters with `.total`**: Follows Prometheus convention
✅ **Include unit when ambiguous**: `response.time.seconds` not just `response.time`
✅ **Use consistent domain prefixes**: All user metrics start with `users.`

❌ **Avoid:**
- CamelCase: `usersCreatedTotal`
- Mixed separators: `users_created.total`
- Abbreviations: `usr.crt.tot`
- Inconsistent naming: `user.created.total` and `users.deleted.count`

### Using Tags for Multi-Dimensional Metrics

Tags (also called labels) add dimensions to your metrics, enabling filtering and aggregation.

**Tag key naming convention:** Use lowercase dot notation (same as metric names)

Micrometer recommends following the same lowercase dot notation for tag keys as you use for metric names. This ensures maximum portability across different monitoring systems, as Micrometer automatically converts the naming convention to match each backend's requirements.

**Example from this project:**

```java
Counter.builder("users.created.total")
       .tag("company.name", companyName)    // Dimension 1
       .tag("country.name", countryName)    // Dimension 2
       .description("Total number of users created")
       .register(meterRegistry)
       .increment();
```

**This creates metrics like:**
```
users_created_total{company_name="Acme Corporation", country_name="United States"} 42
users_created_total{company_name="Tech Innovations Inc", country_name="Canada"} 18
users_created_total{company_name="Siman", country_name="Argentina"} 3
```

**Note:** When exported to Prometheus, Micrometer automatically converts the dot notation tag keys (`company.name`) to snake_case (`company_name`) to match Prometheus conventions.

**Querying with tags in Grafana:**

```promql
# Filter by specific company
users_created_total{company_name="Acme Corporation"}

# Filter by country
users_created_total{country_name="United States"}

# Aggregate across all companies in a country
sum by (country_name) (users_created_total)

# Group by company
sum by (company_name) (users_created_total)
```

**Good tag examples:**

✅ **Low cardinality** (limited, categorical values):
- `environment`: dev, staging, prod
- `region`: us-east, us-west, eu-central
- `version`: 1.0.0, 1.1.0
- `payment.method`: card, paypal, bank_transfer
- `order.status`: pending, completed, failed

❌ **Bad tag examples** (high cardinality):
- `user.id`: unique per user (millions of values)
- `session.id`: unique per session
- `timestamp`: unique per second
- `request.id`: unique per request
- `email`: unique per user

**Why cardinality matters:**

Each unique combination of tags creates a new time series in Prometheus/Mimir. High cardinality can create millions of time series, causing:
- Slow queries
- High memory usage
- Storage explosion
- Query timeouts

**Rule of thumb:** Keep total unique tag combinations under 10,000 per metric.

### Best Practices Summary

**Design:**
- ✅ Create a dedicated metrics service (e.g., `UserMetricsService`)
- ✅ Use dependency injection for `MeterRegistry`
- ✅ Keep metrics logic separate from business logic
- ✅ Initialize gauges at startup with existing data

**Thread Safety:**
- ✅ Use `ConcurrentHashMap` for storing metric references
- ✅ Use `AtomicInteger` or `AtomicDouble` for gauge values
- ✅ Micrometer's `MeterRegistry` is thread-safe

**Registration:**
- ✅ Counters: Safe to register inline (idempotent)
- ✅ Gauges: Prevent duplicates with a tracking Set
- ✅ Always add `.description()` for documentation

**Naming & Tags:**
- ✅ Use dot notation for both metrics and tags: `users.created.total`
- ✅ End counters with `.total`
- ✅ Use dot notation for tag keys: `company.name`, `country.name`
- ✅ Keep tag cardinality low (< 10,000 combinations)

**Integration:**
- ✅ Record metrics after successful operations
- ✅ Don't throw exceptions from metrics code
- ✅ Consider metrics as "observability side effects"

[Back to Table of Contents](#table-of-contents)

---

## Quick Start Example Guide

### 1. Prerequisites

Ensure you have:
- ✅ Docker and Docker Compose installed
- ✅ Java 17+ (if building locally)
- ✅ Maven 3.9+ (if building locally)

### 2. Quick Start

**For local development (both stacks):**
```bash
# Start LGTM
cd observability && docker-compose up -d && cd ..

# Start app
docker-compose up --build
```

**For production deployment**, see detailed documentation:
- Observability stack: [observability/README.md](observability/README.md)
- Application stack: Continue reading this document


**Initial startup takes 2-3 minutes** as Docker builds images and starts all services.

### 3. Access Points

Once running, access these URLs:

| Service | URL | Purpose |
|---------|-----|---------|
| **Application** | http://localhost:8081/api | REST API |
| **Grafana** | http://localhost:3030 | Dashboards (admin/admin) |
| **Alloy UI** | http://localhost:12345 | Telemetry pipeline status |
| **Health Check** | http://localhost:8081/actuator/health | App health |
| **Prometheus Metrics** | http://localhost:8081/actuator/prometheus | Metrics endpoint |

Application Endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET    | `/api`   | List all users |
| GET    | `/api/{id}` | Get specific user |
| POST   | `/api/users` | Create a new user |
| DELETE | `/api/{id}` | Delete a user |
| GET    | `/actuator/health` | Application health check |
| GET    | `/actuator/prometheus` | Prometheus metrics endpoint |
| GET    | `/actuator/metrics` | Spring Boot metrics |


### 4. Sample API Requests

```bash
# List all users
curl http://localhost:8081/api

# Get specific user
curl http://localhost:8081/api/1

# Health check
curl http://localhost:8081/actuator/health

# View Prometheus metrics
curl http://localhost:8081/actuator/prometheus

```
### 5. Architecture Overview

```
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│   Observability Stack           │     │   Application Stack             │
│   (observability/)              │     │   (root)                        │
│                                 │     │                                 │
│   • Grafana (dashboards)        │     │   • Spring Boot App             │
│   • Mimir (metrics)             │     │   • PostgreSQL                  │
│   • Loki (logs)                 │     │   • postgres-exporter           │
│   • Tempo (traces)              │     │                                 │
│   • Alloy (collector)           │     │                                 │
│                                 │     │                                 │
│   Receives telemetry via:       │     │   Sends telemetry via:          │
│   • OTLP endpoint (4318/4317)   │◄────┤   • OTLP (traces/logs/metrics)  │
│   Scrapes metrics from:         │     |   Exposes for scraping:         │
│   • External targets ────────────────►│   • /actuator/prometheus (8081) │
│                                 │     │   • postgres-exporter (9187)    │
│                                 │     │   • node-exporter (9100)        │
└─────────────────────────────────┘     └─────────────────────────────────┘
```

### 6. Deployment Scenarios

#### Scenario 1: Co-located Deployment (Same Host)

Both stacks running on the same machine - ideal for development and testing.

**Quick setup using installation scripts:**

```bash
# Step 1: Install LGTM stack
bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/master/install.sh)
cd observability && docker-compose up -d && cd ..

# Step 2: Instrument your Spring Boot application
# For new projects (requires Spring Boot CLI):
bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/master/setup/java/setup-otel.sh)

# For existing projects (no Spring Boot CLI needed):
cd your-existing-project
bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/master/setup/java/setup-otel.sh)
# Answer "No" when asked about creating a new project

# Step 3: Start application
docker-compose up -d --build
```

**Manual setup** (if not using scripts):

```bash
# Terminal 1: Start LGTM stack
cd observability
docker-compose up -d

# Terminal 2: Start application stack
cd ..
docker-compose up -d
```

**How it works:**
- Application connects to Alloy via `host.docker.internal:4318`
- Alloy scrapes metrics via `host.docker.internal:8081` and `:9187`
- All services accessible on `localhost`
- Default configuration works without modifications

**Access points:**
- Application: http://localhost:8081
- Grafana: http://localhost:3030
- Alloy UI: http://localhost:12345

#### Scenario 2: Distributed Deployment (Different Hosts)

LGTM stack on dedicated observability host, applications on separate hosts - ideal for production.

**On Observability Host (e.g., 10.0.1.100):**

```bash
# Step 1: Install LGTM stack
bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/master/install.sh)

# Step 2: Configure for distributed deployment
cd observability
# Edit .env to configure external scrape targets
echo "SCRAPE_APP_TARGET=10.0.1.101:8081" >> .env
echo "SCRAPE_POSTGRES_TARGET=10.0.1.101:9187" >> .env

# Optional: Configure for production storage (S3 or GCS)
echo "STORAGE_TYPE=s3" >> .env  # or 'gcs' for Google Cloud
# Add cloud credentials if using S3/GCS (see "How to Setup the LGTM Stack" section)

# Step 3: Start LGTM stack
docker-compose up -d
```

**On Application Host (e.g., 10.0.1.101):**

```bash
# Step 1: Instrument application using setup script
cd your-project-directory
bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/master/setup/java/setup-otel.sh)
# Answer "No" for new project (assuming existing project)

# Step 2: Configure to connect to remote LGTM stack
# Edit .env to point to LGTM stack
echo "OTEL_EXPORTER_OTLP_ENDPOINT=http://10.0.1.100:4318" >> .env

# Step 3: Start application
docker-compose up -d --build
```

**Network requirements:**
- App host must reach: `<lgtm-host>:4318` (OTLP endpoint for traces/metrics/logs)
- LGTM host must reach: `<app-host>:8081` (Prometheus metrics scraping)
- LGTM host must reach: `<app-host>:9187` (PostgreSQL metrics, if using postgres)

**Configuration notes:**
- All configuration is managed via `.env` files on each host
- See "How to Setup the LGTM Stack" section for detailed `.env` configuration options
- Consider using TLS and authentication for production deployments
- Adjust retention periods and storage limits based on your requirements


[Back to Table of Contents](#table-of-contents)

---

## Key Configuration Files Reference

### 1. Dockerfile
**Location**: `/Dockerfile`
**Purpose**: Multi-stage build that downloads OTel agent and attaches it to JVM
**Key line**: `ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -javaagent:otel-javaagent.jar -jar app.jar"]`

### 2. docker-compose.yaml
**Location**: `/docker-compose.yaml`
**Purpose**: Defines entire observability stack

### 3. alloy.alloy
**Location**: `/observability/alloy.alloy`
**Purpose**: Alloy telemetry pipeline configuration

### 4. grafana-datasources.yaml
**Location**: `/observability/grafana-datasources.yaml`
**Purpose**: Auto-provision Grafana datasources with correlation

### 5. application.properties
**Location**: `/src/main/resources/application.properties`
**Purpose**: Spring Boot configuration

### 6. logback-spring.xml
**Location**: `/src/main/resources/logback-spring.xml`
**Purpose**: Logging configuration with trace correlation
**Key pattern**: `[traceid=%X{trace_id:-}, spanid=%X{span_id:-}]`

### 7. pom.xml
**Location**: `/pom.xml`
**Purpose**: Maven dependencies
**Key dependencies**:
- Spring Boot Actuator
- Micrometer Prometheus registry

[Back to Table of Contents](#table-of-contents)

---

## Troubleshooting

### Logs Don't Show trace_id

**Symptom**: Log entries show `[traceid=, spanid=]` (empty values)

**Solution**:
1. Verify environment variables are set:
```bash
docker-compose exec app env | grep OTEL_INSTRUMENTATION

# Should show:
# OTEL_INSTRUMENTATION_COMMON_MDC_ENABLED=true
# OTEL_INSTRUMENTATION_LOGBACK_MDC_ADD_BAGGAGE=true
```

2. Check logback-spring.xml pattern includes MDC variables:
```xml
[traceid=%X{trace_id:-}, spanid=%X{span_id:-}]
```

3. Restart application:
```bash
docker-compose restart app
```

### OTel Agent Not Starting

**Symptom**: No traces in Tempo, logs don't mention OpenTelemetry

**Solution**:
1. Check app logs for agent startup:
```bash
docker-compose logs app | grep -i opentelemetry

# Should see:
# [otel.javaagent] OpenTelemetry Javaagent started
```

2. Verify agent JAR exists in container:
```bash
docker-compose exec app ls -l otel-javaagent.jar
```

3. Check ENTRYPOINT includes `-javaagent`:
```bash
docker-compose exec app ps aux | grep javaagent
```

### Prometheus Endpoint Returns 404

**Symptom**: `curl http://localhost:8081/actuator/prometheus` returns 404

**Solution**:
1. Verify Micrometer dependency in pom.xml:
```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>


<dependency>
	<groupId>io.micrometer</groupId>
	<artifactId>micrometer-tracing-bridge-otel</artifactId>
</dependency>
```

2. Check application.properties enables endpoint:
```properties
management.endpoints.web.exposure.include=health,info,prometheus
```

3. Rebuild and restart:
```bash
docker-compose up --build
```

### Alloy Not Scraping Metrics

**Symptom**: Metrics not appearing in Mimir

**Solution**:
1. Check Alloy logs:
```bash
docker-compose logs alloy | grep spring_app

# Look for errors or "Scrape failed"
```

2. Verify Alloy can reach app:
```bash
docker-compose exec alloy wget -O- http://app:8081/actuator/prometheus
```

3. Check alloy-config.alloy has correct target:
```alloy
targets = [{
    "__address__" = "app:8081",  # Must match service name
    ...
}]
```

### Traces Not Appearing in Tempo

**Symptom**: No traces in Grafana/Tempo

**Solution**:
1. Verify OTLP endpoint is correct:
```bash
docker-compose exec app env | grep OTEL_EXPORTER_OTLP_ENDPOINT

# Should be: http://alloy:4318
```

2. Check Alloy is receiving traces:
```bash
docker-compose logs alloy | grep -i trace
```

3. Test OTLP endpoint is reachable:
```bash
docker-compose exec app curl -v http://alloy:4318
```

4. Generate some traces:
```bash
curl http://localhost:8081/api
curl http://localhost:8081/api/1
```

### Database Connection Failed

**Symptom**: App logs show "Connection refused" to PostgreSQL

**Solution**:
1. Check PostgreSQL is healthy:
```bash
docker-compose ps postgres

# Status should show "healthy"
```

2. View PostgreSQL logs:
```bash
docker-compose logs postgres
```

3. Verify connection settings match:
```bash
# In compose.yaml, app service:
DB_URL: jdbc:postgresql://postgres:5432/userdemo
DB_USERNAME: admin
DB_PASSWORD: secret
```

### Grafana Shows "No Data"

**Symptom**: Grafana datasources show "No data" or errors

**Solution**:
1. Check all backend services are running:
```bash
docker-compose ps

# All services should show "Up" or "healthy"
```

2. Test datasource connectivity in Grafana:
   - Go to Configuration → Data Sources
   - Click each datasource (Tempo, Mimir, Loki)
   - Click "Save & Test"
   - Should show green "Data source is working"

3. Verify datasource URLs in grafana-datasources.yaml:
```yaml
- name: Tempo
  url: http://tempo:3200
- name: Mimir
  url: http://mimir:9009/prometheus
- name: Loki
  url: http://loki:3100
```

[Back to Table of Contents](#table-of-contents)

---

## Built with

- Spring Boot 3.5.8
- Java 17
- OpenTelemetry Java Agent
- Micrometer with Prometheus
- Grafana LGTM Stack (Loki, Grafana, Tempo, Mimir)
- Grafana Alloy
- PostgreSQL 16
