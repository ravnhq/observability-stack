# Traffic Generation Scripts

This directory contains bash scripts for generating traffic to the User Demo API for testing, load generation, and observability demonstrations.

## Prerequisites

- **curl**: Command-line tool for making HTTP requests
- **bc**: Basic calculator for floating-point arithmetic
- **Running application**: The User Demo application must be running and accessible

## Scripts

### 1. generate-query-traffic.sh

Generates continuous GET requests to query random users from the API.

**Usage:**
```bash
./scripts/generate-query-traffic.sh
```

**Configuration:**

You can customize behavior using environment variables:

```bash
# Set custom API URL (default: http://localhost:8081)
API_URL=http://localhost:8080 ./scripts/generate-query-traffic.sh

# Set custom user ID range (default: 1-50)
MIN_USER_ID=1 MAX_USER_ID=100 ./scripts/generate-query-traffic.sh

# Set custom delay range in milliseconds (default: 100-2000ms)
MIN_DELAY_MS=500 MAX_DELAY_MS=3000 ./scripts/generate-query-traffic.sh
```

**Features:**
- Queries random user IDs within configured range
- Random delays between 100ms-2s (configurable)
- Color-coded output (green=success, yellow=not found, red=error)
- Statistics tracking (total requests, successful, failed)
- Graceful shutdown with Ctrl+C showing final statistics

**Example Output:**
```
[2025-11-21 10:30:45] GET /api/42 - Status: 200 - User: Alice
[2025-11-21 10:30:47] GET /api/99 - Status: 404 - User not found
[2025-11-21 10:30:48] GET /api/15 - Status: 200 - User: Bob
```

### 2. generate-add-traffic.sh

Generates continuous POST requests to create new users in the API.

**Usage:**
```bash
./scripts/generate-add-traffic.sh
```

**Configuration:**

You can customize behavior using environment variables:

```bash
# Set custom API URL (default: http://localhost:8081)
API_URL=http://localhost:8080 ./scripts/generate-add-traffic.sh

# Set custom delay range in milliseconds (default: 100-2000ms)
MIN_DELAY_MS=500 MAX_DELAY_MS=3000 ./scripts/generate-add-traffic.sh
```

**Features:**
- Creates users with randomly generated names (e.g., "Alice_1732190445123_5678")
- Random delays between 100ms-2s (configurable)
- Color-coded output (green=success, yellow=validation error, red=error)
- Statistics tracking (total requests, successful, failed)
- Graceful shutdown with Ctrl+C showing final statistics

**Example Output:**
```
[2025-11-21 10:35:12] POST /api/users - Status: 201 - Created: id=123, name='Diana_1732190112456_7890'
[2025-11-21 10:35:14] POST /api/users - Status: 201 - Created: id=124, name='Frank_1732190114789_3456'
```

### 3. generate-delete-traffic.sh

Generates continuous DELETE requests to remove random users from the API.

**Usage:**
```bash
./scripts/generate-delete-traffic.sh
```

**Configuration:**

You can customize behavior using environment variables:

```bash
# Set custom API URL (default: http://localhost:8081)
API_URL=http://localhost:8080 ./scripts/generate-delete-traffic.sh

# Set custom user ID range (default: 1-50)
MIN_USER_ID=1 MAX_USER_ID=100 ./scripts/generate-delete-traffic.sh

# Set custom delay range in milliseconds (default: 100-2000ms)
MIN_DELAY_MS=500 MAX_DELAY_MS=3000 ./scripts/generate-delete-traffic.sh
```

**Features:**
- Deletes random user IDs within configured range
- Random delays between 100ms-2s (configurable)
- Color-coded output (green=success, red=error/not found)
- Statistics tracking (total requests, successful, failed)
- Graceful shutdown with Ctrl+C showing final statistics

**Example Output:**
```
[2025-11-21 10:40:12] DELETE /api/123 - Status: 204 - User deleted
[2025-11-21 10:40:14] DELETE /api/999 - Status: 500 - Request failed (Likely user not found)
```

## Use Cases

### Load Testing
Run both scripts simultaneously to simulate realistic mixed traffic:
```bash
# Terminal 1: Generate query traffic
./scripts/generate-query-traffic.sh

# Terminal 2: Generate add user traffic
./scripts/generate-add-traffic.sh
```

### Observability Testing
Use these scripts to generate traces and logs for:
- Testing OpenTelemetry integration
- Populating Grafana dashboards
- Verifying Loki log aggregation
- Testing distributed tracing with Tempo

### Database Performance Testing
Monitor database performance under load:
```bash
# Generate high-frequency queries
MIN_DELAY_MS=10 MAX_DELAY_MS=50 ./scripts/generate-query-traffic.sh
```

## Stopping Scripts

Press **Ctrl+C** to stop any running script. The script will display statistics before exiting:

```
================================================
Statistics:
Total Requests: 245
Successful: 238
Failed: 7
================================================
```

## Troubleshooting

**Script won't start:**
- Ensure scripts are executable: `chmod +x scripts/*.sh`
- Verify `curl` and `bc` are installed: `which curl bc`

**Connection errors:**
- Verify the application is running: `curl http://localhost:8081/api`
- Check the API_URL environment variable matches your setup

**Permission denied:**
- Make scripts executable: `chmod +x scripts/*.sh`

## API Endpoints

The scripts interact with these endpoints:

- `GET /api/{id}` - Retrieve user by ID (used by generate-query-traffic.sh)
  - Returns: UserDto with nested country and company objects
- `POST /api/users` - Create new user (used by generate-add-traffic.sh)
  - Request body: `{"name": "string", "countryId": number, "companyId": number}`
  - Valid countryId values: 1, 2, 3 (from seed data: United States, Canada, Germany)
  - Valid companyId values: 1, 2, 3 (from seed data: Acme Corporation, Tech Innovations Inc, Engineering Solutions GmbH)
  - Returns: UserDto with nested country and company objects
- `DELETE /api/{id}` - Delete user by ID (used by generate-delete-traffic.sh)

### Seed Data

The application starts with the following seed data:

**Countries:**
- ID 1: United States
- ID 2: Canada
- ID 3: Germany

**Companies:**
- ID 1: Acme Corporation (United States)
- ID 2: Tech Innovations Inc (Canada)
- ID 3: Engineering Solutions GmbH (Germany)

**Users (seed):**
- IDs 1-5: Initial test users with valid country and company assignments

### Response Format

All user endpoints now return nested DTOs with full object details:

```json
{
  "id": 123,
  "name": "Alice_1732190112456_7890",
  "country": {
    "id": 1,
    "name": "United States"
  },
  "company": {
    "id": 1,
    "name": "Acme Corporation",
    "country": {
      "id": 1,
      "name": "United States"
    }
  }
}
```
