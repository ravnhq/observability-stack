#!/bin/bash

# Test script for GraphQL user query operations

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/common-graphql.sh"

# Check dependencies
check_dependencies

# Validate GraphQL connection
validate_graphql_connection

log_info "Starting GraphQL query testing..."
log_info "GraphQL URL: $GRAPHQL_ENDPOINT"
log_info "Delay range: ${MIN_DELAY}ms - ${MAX_DELAY}ms"
log_info "Query mix: 70% individual users, 30% batch queries"
log_info "Press Ctrl+C to stop"
echo ""

# User IDs cache
USER_IDS=()
COMPANY_IDS=()
COUNTRY_IDS=()
REQUEST_COUNT=0
BATCH_REQUEST_COUNT=0
INDIVIDUAL_REQUEST_COUNT=0
REFRESH_INTERVAL=5

# Fetch all users and extract IDs
fetch_users() {
    log_info "Fetching all users via GraphQL..."

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

        # Extract unique company and country IDs for filtering
        COMPANY_IDS=($(echo "$users_data" | jq -r '.[].company.id // empty' 2>/dev/null | sort -u))
        COUNTRY_IDS=($(echo "$users_data" | jq -r '.[].country.id // empty' 2>/dev/null | sort -u))

        if [ ${#USER_IDS[@]} -eq 0 ]; then
            log_warning "No users found in the system"
            return 1
        else
            log_info "Found ${#USER_IDS[@]} users, ${#COMPANY_IDS[@]} companies, ${#COUNTRY_IDS[@]} countries"
            return 0
        fi
    else
        log_error "Failed to fetch users (HTTP status: $status_code)"
        return 1
    fi
}

# Query individual user by ID
query_individual_user() {
    local user_id=$1

    log_info "Querying individual user with ID: $user_id"

    local query=$(build_user_query)
    local variables=$(jq -n --arg id "$user_id" '{id: $id}')

    ((TOTAL_REQUESTS++))
    ((INDIVIDUAL_REQUEST_COUNT++))
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
                log_warning "User not found: User may have been deleted"
                # Remove this ID from cache
                remove_id_from_cache "$user_id"
            else
                log_graphql_error "$body"
            fi
        else
            ((SUCCESSFUL_REQUESTS++))

            # Extract user details from response
            local user_data=$(echo "$body" | jq -r '.data.user' 2>/dev/null)
            local user_email=$(echo "$user_data" | jq -r '.email')
            local user_name=$(echo "$user_data" | jq -r '.name')
            local country_name=$(echo "$user_data" | jq -r '.country.name // "N/A"')
            local company_name=$(echo "$user_data" | jq -r '.company.name // "N/A"')

            log_success "Retrieved user - Email: $user_email, Name: $user_name, Country: $country_name, Company: $company_name"
        fi
    else
        ((FAILED_REQUESTS++))

        if [ -z "$status_code" ]; then
            log_error "Network error: Failed to connect to GraphQL endpoint"
        else
            log_error "HTTP error ($status_code): $body"
        fi
    fi
}

# Query batch users with optional filters
query_batch_users() {
    log_info "Querying batch users..."

    local query=$(build_users_query)
    local variables='{}'
    local filter_description="no filter"

    # Randomly decide which filter to use (if any)
    local filter_choice=$((RANDOM % 3))

    if [ $filter_choice -eq 0 ] && [ ${#COMPANY_IDS[@]} -gt 0 ]; then
        # Filter by company
        local random_company_index=$((RANDOM % ${#COMPANY_IDS[@]}))
        local company_id=${COMPANY_IDS[$random_company_index]}
        variables=$(jq -n --arg companyId "$company_id" '{companyId: $companyId}')
        filter_description="companyId: $company_id"
    elif [ $filter_choice -eq 1 ] && [ ${#COUNTRY_IDS[@]} -gt 0 ]; then
        # Filter by country
        local random_country_index=$((RANDOM % ${#COUNTRY_IDS[@]}))
        local country_id=${COUNTRY_IDS[$random_country_index]}
        variables=$(jq -n --arg countryId "$country_id" '{countryId: $countryId}')
        filter_description="countryId: $country_id"
    fi

    log_info "Filter: $filter_description"

    ((TOTAL_REQUESTS++))
    ((BATCH_REQUEST_COUNT++))
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
            log_graphql_error "$body"
        else
            ((SUCCESSFUL_REQUESTS++))

            # Extract users data
            local users_data=$(echo "$body" | jq -r '.data.users' 2>/dev/null)
            local user_count=$(echo "$users_data" | jq 'length' 2>/dev/null)

            log_success "Retrieved $user_count users"

            # Show sample of first 3 users
            if [ "$user_count" -gt 0 ]; then
                local sample_users=$(echo "$users_data" | jq -r '.[0:3] | .[] | "\(.email) - \(.name)"' 2>/dev/null)
                log_info "Sample users:"
                while IFS= read -r line; do
                    log_info "  - $line"
                done <<< "$sample_users"
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

    # Randomly decide between individual query (70%) and batch query (30%)
    if [ $((RANDOM % 10)) -lt 7 ]; then
        # Individual user query
        random_index=$((RANDOM % ${#USER_IDS[@]}))
        user_id=${USER_IDS[$random_index]}
        query_individual_user "$user_id"
    else
        # Batch users query
        query_batch_users
    fi

    # Generate random delay
    delay=$(generate_random_delay)
    log_info "Waiting ${delay}ms before next request..."
    sleep_ms "$delay"
    echo ""
done
