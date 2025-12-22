#!/bin/bash

# Test script for POST /users endpoint

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/common.sh"

# Check dependencies
check_dependencies

# Validate API connection
validate_api_connection

log_info "Starting POST endpoint testing..."
log_info "API URL: $API_URL"
log_info "Delay range: ${MIN_DELAY}ms - ${MAX_DELAY}ms"
log_info "Press Ctrl+C to stop"
echo ""

# Country and Company IDs cache
COUNTRY_IDS=()
COMPANY_IDS=()

# Generate random string
generate_random_string() {
    local length=$1
    LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# Generate random email
generate_email() {
    local timestamp=$(date +%s)
    local random=$(generate_random_string 6)
    echo "user_${timestamp}_${random}@test.local"
}

# Generate random name
generate_name() {
    local random=$(generate_random_string 8)
    echo "User_${random}"
}

# Generate random password
generate_password() {
    generate_random_string 12
}

# Fetch all countries and extract IDs
fetch_countries() {
    log_info "Fetching available countries..."

    response=$(http_request "GET" "$API_URL/countries")
    {
        read -r body
        read -r status_code
    } < <(parse_response "$response")

    if [ "$status_code" = "200" ]; then
        # Extract country IDs
        COUNTRY_IDS=($(echo "$body" | jq -r '.[].id' 2>/dev/null))

        if [ ${#COUNTRY_IDS[@]} -eq 0 ]; then
            log_error "No countries found in the system. Please create countries first."
            return 1
        else
            log_info "Found ${#COUNTRY_IDS[@]} countries"
            return 0
        fi
    else
        log_error "Failed to fetch countries (status: $status_code)"
        return 1
    fi
}

# Fetch all companies and extract IDs
fetch_companies() {
    log_info "Fetching available companies..."

    response=$(http_request "GET" "$API_URL/companies")
    {
        read -r body
        read -r status_code
    } < <(parse_response "$response")

    if [ "$status_code" = "200" ]; then
        # Extract company IDs
        COMPANY_IDS=($(echo "$body" | jq -r '.[].id' 2>/dev/null))

        if [ ${#COMPANY_IDS[@]} -eq 0 ]; then
            log_error "No companies found in the system. Please create companies first."
            return 1
        else
            log_info "Found ${#COMPANY_IDS[@]} companies"
            return 0
        fi
    else
        log_error "Failed to fetch companies (status: $status_code)"
        return 1
    fi
}

# Fetch countries and companies on startup
log_info "Initializing..."
fetch_countries || exit 1
fetch_companies || exit 1
echo ""

# Main loop
while true; do
    # Generate random user data
    email=$(generate_email)
    name=$(generate_name)
    password=$(generate_password)

    # Select random country and company
    random_country_index=$((RANDOM % ${#COUNTRY_IDS[@]}))
    country_id=${COUNTRY_IDS[$random_country_index]}

    random_company_index=$((RANDOM % ${#COMPANY_IDS[@]}))
    company_id=${COMPANY_IDS[$random_company_index]}

    # Create JSON payload
    json_payload=$(jq -n \
        --arg email "$email" \
        --arg name "$name" \
        --arg password "$password" \
        --arg countryId "$country_id" \
        --arg companyId "$company_id" \
        '{email: $email, name: $name, password: $password, countryId: $countryId, companyId: $companyId}')

    log_info "Creating user..."

    # Make POST request
    ((TOTAL_REQUESTS++))
    response=$(http_request "POST" "$API_URL/users" "$json_payload")

    # Parse response
    {
        read -r body
        read -r status_code
    } < <(parse_response "$response")

    # Check status code
    if [ "$status_code" = "201" ]; then
        ((SUCCESSFUL_REQUESTS++))

        # Extract user details from response
        user_id=$(echo "$body" | jq -r '.id')
        user_email=$(echo "$body" | jq -r '.email')
        user_name=$(echo "$body" | jq -r '.name')
        country_name=$(echo "$body" | jq -r '.country.name')
        company_name=$(echo "$body" | jq -r '.company.name')

        log_success "User created - ID: $user_id, Email: $user_email, Name: $user_name, Country: $country_name, Company: $company_name"
    else
        ((FAILED_REQUESTS++))

        if [ "$status_code" = "400" ]; then
            error_message=$(echo "$body" | jq -r '.message // "Validation error"')
            log_error "Validation error (400): $error_message"
        elif [ "$status_code" = "409" ]; then
            log_error "Conflict (409): User already exists"
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
