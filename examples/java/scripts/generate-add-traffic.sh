#!/bin/bash

# Traffic generation script for adding random users
# This script continuously makes POST requests to create new users

set -e

# Configuration
API_URL="${API_URL:-http://localhost:8081}"
MIN_DELAY_MS="${MIN_DELAY_MS:-100}"
MAX_DELAY_MS="${MAX_DELAY_MS:-2000}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "User Creation Traffic Generator"
echo "================================================"
echo "API URL: $API_URL"
echo "Delay Range: ${MIN_DELAY_MS}ms - ${MAX_DELAY_MS}ms"
echo "================================================"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Counter for statistics
total_requests=0
successful_requests=0
failed_requests=0

# Array of random name prefixes for variety
name_prefixes=("Alice" "Bob" "Charlie" "Diana" "Eve" "Frank" "Grace" "Henry" "Iris" "Jack" "Kate" "Leo" "Maria" "Nathan" "Olivia" "Peter" "Quinn" "Rachel" "Steve" "Tina")

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

# Function to generate random user name
generate_user_name() {
    local timestamp=$(date +%s%N | cut -b1-13)  # milliseconds
    local random_num=$((RANDOM % 10000))
    local prefix_index=$((RANDOM % ${#name_prefixes[@]}))
    local prefix="${name_prefixes[$prefix_index]}"
    echo "${prefix}_${timestamp}_${random_num}"
}

# Trap Ctrl+C to show statistics before exiting
trap 'echo ""; echo "================================================"; echo "Statistics:"; echo "Total Requests: $total_requests"; echo "Successful: $successful_requests"; echo "Failed: $failed_requests"; echo "================================================"; exit 0' INT

# Main loop
while true; do
    # Generate random user name
    user_name=$(generate_user_name)

    # Get timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Randomly select from valid country/company IDs
    # IDs 1-3 correspond to seed data: USA, Canada, Germany and their respective companies
    country_ids=(1 2 3)
    company_ids=(1 2 3)
    random_country_index=$((RANDOM % ${#country_ids[@]}))
    random_company_index=$((RANDOM % ${#company_ids[@]}))
    country_id="${country_ids[$random_country_index]}"
    company_id="${company_ids[$random_company_index]}"

    # Create JSON payload
    json_payload=$(printf '{"name":"%s","countryId":%d,"companyId":%d}' "$user_name" "$country_id" "$company_id")

    # Make POST request and capture response code
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        "${API_URL}/api/users" 2>&1)
    http_code=$(echo "$response" | tail -n 1)
    response_body=$(echo "$response" | sed '$d')

    total_requests=$((total_requests + 1))

    # Log the request
    if [ "$http_code" = "201" ]; then
        successful_requests=$((successful_requests + 1))
        user_id=$(echo "$response_body" | grep -o '"id":[0-9]*' | head -n 1 | cut -d':' -f2)
        echo -e "${GREEN}[${timestamp}]${NC} POST /api/users - Status: ${http_code} - Created: id=${user_id}, name='${user_name}'"
    elif [ "$http_code" = "400" ]; then
        failed_requests=$((failed_requests + 1))
        echo -e "${YELLOW}[${timestamp}]${NC} POST /api/users - Status: ${http_code} - Bad request (validation failed)"
    else
        failed_requests=$((failed_requests + 1))
        echo -e "${RED}[${timestamp}]${NC} POST /api/users - Status: ${http_code} - Request failed"
    fi

    # Random delay between requests
    delay=$(random_delay)
    sleep "$delay"
done
