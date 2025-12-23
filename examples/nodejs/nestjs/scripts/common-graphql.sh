#!/bin/bash

# Common utilities for GraphQL test scripts

# Source the common HTTP utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# GraphQL endpoint
GRAPHQL_ENDPOINT="${API_URL}/graphql"

# Execute GraphQL request
# Parameters:
#   $1 - GraphQL query string
#   $2 - JSON variables object (default: {})
graphql_request() {
    local query=$1
    local variables=${2:-'{}'}

    # Build GraphQL JSON payload
    local payload=$(jq -n \
        --arg query "$query" \
        --argjson variables "$variables" \
        '{query: $query, variables: $variables}')

    # Execute POST request using common http_request
    http_request "POST" "$GRAPHQL_ENDPOINT" "$payload"
}

# Build GraphQL query: GetUsers with optional filters
build_users_query() {
    cat <<'EOF'
query GetUsers($companyId: ID, $countryId: ID) {
  users(companyId: $companyId, countryId: $countryId) {
    id
    email
    name
    country {
      id
      name
      createdAt
      updatedAt
    }
    company {
      id
      name
      createdAt
      updatedAt
    }
    createdAt
    updatedAt
  }
}
EOF
}

# Build GraphQL query: GetUser by ID
build_user_query() {
    cat <<'EOF'
query GetUser($id: ID!) {
  user(id: $id) {
    id
    email
    name
    country {
      id
      name
      createdAt
      updatedAt
    }
    company {
      id
      name
      createdAt
      updatedAt
    }
    createdAt
    updatedAt
  }
}
EOF
}

# Build GraphQL mutation: DeleteUser
build_delete_user_mutation() {
    cat <<'EOF'
mutation DeleteUser($id: ID!) {
  deleteUser(id: $id)
}
EOF
}

# Check if GraphQL response contains errors
has_graphql_errors() {
    local body=$1
    local errors=$(echo "$body" | jq -r '.errors // empty' 2>/dev/null)

    if [ -n "$errors" ] && [ "$errors" != "null" ]; then
        return 0  # Has errors
    else
        return 1  # No errors
    fi
}

# Extract GraphQL error message
get_graphql_error_message() {
    local body=$1
    echo "$body" | jq -r '.errors[0].message // "Unknown GraphQL error"' 2>/dev/null
}

# Extract GraphQL error code
get_graphql_error_code() {
    local body=$1
    echo "$body" | jq -r '.errors[0].extensions.code // "UNKNOWN"' 2>/dev/null
}

# Extract data from GraphQL response
extract_graphql_data() {
    local body=$1
    echo "$body" | jq -r '.data' 2>/dev/null
}

# Log GraphQL error with details
log_graphql_error() {
    local body=$1
    local error_message=$(get_graphql_error_message "$body")
    local error_code=$(get_graphql_error_code "$body")

    log_error "GraphQL error [$error_code]: $error_message"
}

# Remove ID from array (helper for cache management)
remove_id_from_cache() {
    local id_to_remove=$1
    local new_array=()

    for id in "${USER_IDS[@]}"; do
        if [ "$id" != "$id_to_remove" ]; then
            new_array+=("$id")
        fi
    done

    USER_IDS=("${new_array[@]}")
}

# Extract field from JSON array of objects
extract_field_from_array() {
    local json_array=$1
    local field_name=$2
    echo "$json_array" | jq -r ".[].${field_name}" 2>/dev/null
}

# Validate GraphQL endpoint connection
validate_graphql_connection() {
    log_info "Validating GraphQL connection to $GRAPHQL_ENDPOINT..."

    local test_query='query HealthCheck { __typename }'
    local payload=$(jq -n --arg query "$test_query" '{query: $query}')

    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        -w "\n%{http_code}" \
        --max-time 5 \
        --connect-timeout 2 \
        "$GRAPHQL_ENDPOINT" 2>/dev/null)

    local status_code=$(echo "$response" | tail -n 1)

    if [ -z "$status_code" ] || [ "$status_code" != "200" ]; then
        log_error "Cannot connect to GraphQL endpoint at $GRAPHQL_ENDPOINT"
        log_error "Please ensure the application is running"
        exit 1
    fi

    log_success "GraphQL connection validated"
}
