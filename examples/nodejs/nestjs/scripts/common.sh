#!/bin/bash

# Common utilities for user endpoint test scripts

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Environment variables with defaults
API_URL="${API_URL:-http://localhost:3000}"
MIN_DELAY="${MIN_DELAY:-50}"
MAX_DELAY="${MAX_DELAY:-1000}"

# Statistics counters
TOTAL_REQUESTS=0
SUCCESSFUL_REQUESTS=0
FAILED_REQUESTS=0

# Log with timestamp
log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} INFO: $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} SUCCESS: $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ERROR: $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} WARNING: $1"
}

# Parse delay value (supports numbers in ms)
parse_delay_ms() {
    local delay=$1
    # Remove 'ms' suffix if present
    delay=${delay%ms}
    echo "$delay"
}

# Generate random delay between MIN_DELAY and MAX_DELAY (in milliseconds)
generate_random_delay() {
    local min=$(parse_delay_ms "$MIN_DELAY")
    local max=$(parse_delay_ms "$MAX_DELAY")

    if [ "$min" -ge "$max" ]; then
        echo "$min"
        return
    fi

    local range=$((max - min))
    local random_value=$((RANDOM % range))
    local delay=$((min + random_value))

    echo "$delay"
}

# Sleep for milliseconds
sleep_ms() {
    local ms=$1
    local seconds=$(echo "scale=3; $ms / 1000" | bc)
    sleep "$seconds"
}

# Check if required dependencies are installed
check_dependencies() {
    local missing_deps=()

    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi

    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi

    if ! command -v bc &> /dev/null; then
        missing_deps+=("bc")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install missing dependencies and try again"
        exit 1
    fi
}

# Validate API connection
validate_api_connection() {
    log_info "Validating API connection to $API_URL..."

    local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 --connect-timeout 2 "$API_URL/users" 2>/dev/null)

    if [ -z "$response" ]; then
        log_error "Cannot connect to API at $API_URL"
        log_error "Please ensure the application is running"
        exit 1
    fi

    log_success "API connection validated"
}

# Make HTTP request and return response with status code
http_request() {
    local method=$1
    local url=$2
    local data=$3

    local response
    if [ -n "$data" ]; then
        response=$(curl -s -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            -w "\n%{http_code}" \
            --max-time 5 \
            --connect-timeout 2 \
            "$url" 2>/dev/null)
    else
        response=$(curl -s -X "$method" \
            -w "\n%{http_code}" \
            --max-time 5 \
            --connect-timeout 2 \
            "$url" 2>/dev/null)
    fi

    echo "$response"
}

# Parse HTTP response to get body and status code
parse_response() {
    local response=$1
    local last_line=$(echo "$response" | tail -n 1)
    local body=$(echo "$response" | sed '$d')

    echo "$body"
    echo "$last_line"
}

# Handle script exit
cleanup() {
    echo ""
    log_info "Shutting down..."
    log_info "Statistics:"
    log_info "  Total requests: $TOTAL_REQUESTS"
    log_info "  Successful: $SUCCESSFUL_REQUESTS"
    log_info "  Failed: $FAILED_REQUESTS"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM
