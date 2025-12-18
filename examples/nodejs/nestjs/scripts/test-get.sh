#!/bin/bash

# Test script for GET /users endpoints

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/common.sh"

# Check dependencies
check_dependencies

# Validate API connection
validate_api_connection

log_info "Starting GET endpoint testing..."
log_info "API URL: $API_URL"
log_info "Delay range: ${MIN_DELAY}ms - ${MAX_DELAY}ms"
log_info "Press Ctrl+C to stop"
echo ""

# User IDs cache
USER_IDS=()
REQUEST_COUNT=0
REFRESH_INTERVAL=10

# Fetch all users and extract IDs
fetch_users() {
    log_info "Fetching all users..."

    response=$(http_request "GET" "$API_URL/users")
    {
        read -r body
        read -r status_code
    } < <(parse_response "$response")

    if [ "$status_code" = "200" ]; then
        # Extract user IDs
        USER_IDS=($(echo "$body" | jq -r '.[].id' 2>/dev/null))

        if [ ${#USER_IDS[@]} -eq 0 ]; then
            log_warning "No users found in the system"
            return 1
        else
            log_info "Found ${#USER_IDS[@]} users"
            return 0
        fi
    else
        log_error "Failed to fetch users (status: $status_code)"
        return 1
    fi
}

# Main loop
while true; do
    ((REQUEST_COUNT++))

    # Refresh user list every REFRESH_INTERVAL requests
    if [ $((REQUEST_COUNT % REFRESH_INTERVAL)) -eq 1 ]; then
        fetch_users
        users_available=$?
    fi

    # Check if users are available
    if [ ${#USER_IDS[@]} -eq 0 ]; then
        log_warning "No users available to query. Waiting..."

        # Wait longer when no users available
        delay=$((MAX_DELAY * 2))
        log_info "Waiting ${delay}ms before retry..."
        sleep_ms "$delay"
        echo ""
        continue
    fi

    # Select random user ID
    random_index=$((RANDOM % ${#USER_IDS[@]}))
    user_id=${USER_IDS[$random_index]}

    log_info "Getting user with ID: $user_id"

    # Make GET request for specific user
    ((TOTAL_REQUESTS++))
    response=$(http_request "GET" "$API_URL/users/$user_id")

    # Parse response
    {
        read -r body
        read -r status_code
    } < <(parse_response "$response")

    # Check status code
    if [ "$status_code" = "200" ]; then
        ((SUCCESSFUL_REQUESTS++))

        # Extract user details from response
        user_email=$(echo "$body" | jq -r '.email')
        user_name=$(echo "$body" | jq -r '.name')

        log_success "Retrieved user - Email: $user_email, Name: $user_name"
    else
        ((FAILED_REQUESTS++))

        if [ "$status_code" = "404" ]; then
            log_warning "User not found (404): User may have been deleted"
            # Remove this ID from cache
            USER_IDS=("${USER_IDS[@]/$user_id}")
        elif [ "$status_code" = "500" ]; then
            log_error "Server error (500): Internal server error"
        elif [ -z "$status_code" ]; then
            log_error "Network error: Failed to connect to API"
        else
            log_error "Unexpected error ($status_code): $body"
        fi
    fi

    # Generate random delay
    delay=$(generate_random_delay)
    log_info "Waiting ${delay}ms before next request..."
    sleep_ms "$delay"
    echo ""
done
