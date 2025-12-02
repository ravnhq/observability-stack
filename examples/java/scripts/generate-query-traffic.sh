#!/bin/bash

# Traffic generation script for querying random users
# This script continuously makes GET requests to the user API

set -e

# Configuration
API_URL="${API_URL:-http://localhost:8081}"
MIN_USER_ID="${MIN_USER_ID:-1}"
MAX_USER_ID="${MAX_USER_ID:-50}"
MIN_DELAY_MS="${MIN_DELAY_MS:-100}"
MAX_DELAY_MS="${MAX_DELAY_MS:-2000}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "User Query Traffic Generator"
echo "================================================"
echo "API URL: $API_URL"
echo "User ID Range: $MIN_USER_ID - $MAX_USER_ID"
echo "Delay Range: ${MIN_DELAY_MS}ms - ${MAX_DELAY_MS}ms"
echo "================================================"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Counter for statistics
total_requests=0
successful_requests=0
failed_requests=0

# Function to generate random number in range
random_in_range() {
    local min=$1
    local max=$2
    echo $((min + RANDOM % (max - min + 1)))
}

# Function to generate random delay in milliseconds
random_delay() {
    local delay_ms=$(random_in_range $MIN_DELAY_MS $MAX_DELAY_MS)
    echo "scale=3; $delay_ms / 1000" | bc
}

# Trap Ctrl+C to show statistics before exiting
trap 'echo ""; echo "================================================"; echo "Statistics:"; echo "Total Requests: $total_requests"; echo "Successful: $successful_requests"; echo "Failed: $failed_requests"; echo "================================================"; exit 0' INT

# Main loop
while true; do
    # Generate random user ID
    user_id=$(random_in_range $MIN_USER_ID $MAX_USER_ID)

    # Get timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Make request and capture response code
    response=$(curl -s -w "\n%{http_code}" "${API_URL}/api/${user_id}" 2>&1)
    http_code=$(echo "$response" | tail -n 1)
    response_body=$(echo "$response" | sed '$d')

    total_requests=$((total_requests + 1))

    # Log the request
    if [ "$http_code" = "200" ]; then
        successful_requests=$((successful_requests + 1))
        user_name=$(echo "$response_body" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | paste -sd "," -)
        echo -e "${GREEN}[${timestamp}]${NC} GET /api/${user_id} - Status: ${http_code} - User: ${user_name}"
    elif [ "$http_code" = "404" ]; then
        successful_requests=$((successful_requests + 1))
        echo -e "${YELLOW}[${timestamp}]${NC} GET /api/${user_id} - Status: ${http_code} - User not found"
    else
        failed_requests=$((failed_requests + 1))
        echo -e "${RED}[${timestamp}]${NC} GET /api/${user_id} - Status: ${http_code} - Request failed"
    fi

    # Random delay between requests
    delay=$(random_delay)
    sleep "$delay"
done
