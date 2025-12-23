#!/bin/bash

# Test script for GraphQL user delete operations

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/common-graphql.sh"

# Check dependencies
check_dependencies

# Validate GraphQL connection
validate_graphql_connection

log_info "Starting GraphQL delete testing..."
log_info "GraphQL URL: $GRAPHQL_ENDPOINT"
log_info "Delay range: ${MIN_DELAY}ms - ${MAX_DELAY}ms"
log_info "Press Ctrl+C to stop"
echo ""

# User IDs cache
USER_IDS=()
REQUEST_COUNT=0
REFRESH_INTERVAL=5

# Fetch all users and extract IDs
fetch_users() {
    log_info "Refreshing user list via GraphQL..."

    local query=$(build_users_query)
    local variables='{}'

    response=$(graphql_request "$query" "$variables")
    {
        read -r body
        read -r status_code
    } < <(parse_response "$response")

    if [ "$status_code" = "200" ]; then
        if has_graphql_errors "$body"; then
            log_graphql_error "$body"
            return 1
        fi

        # Extract user data
        local users_data=$(echo "$body" | jq -r '.data.users' 2>/dev/null)

        if [ -z "$users_data" ] || [ "$users_data" = "null" ]; then
            log_warning "No users found in the system"
            return 1
        fi

        # Extract user IDs
        USER_IDS=($(echo "$users_data" | jq -r '.[].id' 2>/dev/null))

        if [ ${#USER_IDS[@]} -eq 0 ]; then
            log_warning "No users found in the system"
            return 1
        else
            log_info "Available users to delete: ${#USER_IDS[@]}"
            return 0
        fi
    else
        log_error "Failed to fetch users (HTTP status: $status_code)"
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
        log_info "No users available to delete. Waiting for users to be created..."

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

    log_info "Deleting user with ID: $user_id"

    # Make DELETE mutation request
    ((TOTAL_REQUESTS++))
    local query=$(build_delete_user_mutation)
    local variables=$(jq -n --arg id "$user_id" '{id: $id}')
    response=$(graphql_request "$query" "$variables")

    # Parse response
    {
        read -r body
        read -r status_code
    } < <(parse_response "$response")

    # Check status code
    if [ "$status_code" = "200" ]; then
        if has_graphql_errors "$body"; then
            ((FAILED_REQUESTS++))

            local error_message=$(get_graphql_error_message "$body")

            # Check if user not found
            if [[ "$error_message" =~ "not found" ]] || [[ "$error_message" =~ "User not found" ]]; then
                log_warning "User not found: User may have been already deleted"
                # Remove this ID from cache
                remove_id_from_cache "$user_id"
            else
                log_graphql_error "$body"
            fi
        else
            # Check if delete was successful
            local delete_result=$(echo "$body" | jq -r '.data.deleteUser' 2>/dev/null)

            if [ "$delete_result" = "true" ]; then
                ((SUCCESSFUL_REQUESTS++))

                # Remove from cache
                remove_id_from_cache "$user_id"

                log_success "User deleted - ID: $user_id"
                log_info "Remaining users in cache: ${#USER_IDS[@]}"
            else
                ((FAILED_REQUESTS++))
                log_error "Delete mutation returned false for user ID: $user_id"
            fi
        fi
    else
        ((FAILED_REQUESTS++))

        if [ -z "$status_code" ]; then
            log_error "Network error: Failed to connect to GraphQL endpoint"
        else
            log_error "HTTP error ($status_code): $body"
        fi
    fi

    # Generate random delay
    delay=$(generate_random_delay)
    log_info "Waiting ${delay}ms before next request..."
    sleep_ms "$delay"
    echo ""
done
