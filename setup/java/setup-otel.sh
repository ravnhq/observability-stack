#!/bin/bash

# ============================================================================
# Spring Boot OpenTelemetry Instrumentation Setup Script
# ============================================================================
# Version: 1.0.0
# Description: Automates the setup of Spring Boot applications with
#              OpenTelemetry instrumentation
# ============================================================================

set -e
set -E

# ============================================================================
# Constants and Global Variables
# ============================================================================

SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Remote template download configuration
REPO_URL="https://github.com/ravnhq/observability-stack"
DEFAULT_BRANCH="master"
BRANCH="${DEFAULT_BRANCH}"
TEMP_DIR=""        # Temp directory path for downloaded templates
TEMPLATE_DIR=""    # Will be set to TEMP_DIR after download
CLEANUP_REQUIRED=false

# Template files (same for all templates)
TEMPLATE_FILES=(
    "Dockerfile"
    "docker-compose.yaml"
    ".env.example"
    "application.properties"
    "application.yaml"
    "logback-spring.xml"
)

# Supported Java versions
SUPPORTED_JAVA_VERSIONS=(17 21 25)

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global state
declare -a ERRORS=()
declare -a WARNINGS=()
PROJECT_NAME=""
JAVA_VERSION=""
SELECTED_TEMPLATE=""
DRY_RUN=false

# File copy statistics
FILES_COPIED=0
FILES_SKIPPED=0
FILES_FAILED=0

# ============================================================================
# Utility Functions - Output
# ============================================================================

print_header() {
    local title="$1"
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    printf "${BLUE}║  %-58s║${NC}\n" "$title"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    local step_num="$1"
    local step_desc="$2"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}STEP $step_num: $step_desc${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}" >&2
}

print_error() {
    local message="$1"
    local should_exit="${2:-true}"
    echo -e "${RED}ERROR: $message${NC}" >&2
    ERRORS+=("$message")
    if [[ "$should_exit" == true ]]; then
        echo -e "${RED}Setup aborted due to errors.${NC}" >&2
        exit 1
    fi
}

print_warning() {
    local message="$1"
    echo -e "${YELLOW}⚠ WARNING: $message${NC}" >&2
    WARNINGS+=("$message")
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ============================================================================
# Validation Functions
# ============================================================================

validate_java_version() {
    local version="$1"
    for supported in "${SUPPORTED_JAVA_VERSIONS[@]}"; do
        if [[ "$version" == "$supported" ]]; then
            return 0
        fi
    done
    return 1
}

validate_package_name() {
    local package_name="$1"

    # Basic validation: lowercase letters, numbers, dots, hyphens
    if [[ "$package_name" =~ ^[a-z][a-z0-9._-]*$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_spring_cli() {
    print_info "Checking for Spring CLI..."
    if ! command -v spring &> /dev/null; then
        print_error "Spring Boot CLI not found. Please install it first.

Installation instructions:
https://docs.spring.io/spring-boot/installing.html#getting-started.installing.cli" true
    fi
    local spring_version=$(spring --version 2>&1 | head -1)
    print_success "Spring Boot CLI found: $spring_version"
}

validate_project_structure() {
    if [[ ! -d "src/main/resources" ]]; then
        print_warning "Directory src/main/resources does not exist"
        if prompt_yes_no "Create src/main/resources directory?" "y"; then
            mkdir -p src/main/resources
            print_success "Created src/main/resources"
        else
            print_error "Cannot continue without src/main/resources" true
        fi
    fi
}

# ============================================================================
# Detection Functions
# ============================================================================

detect_build_tool() {
    if [[ -f "pom.xml" ]]; then
        echo "maven"
    elif [[ -f "build.gradle.kts" ]] || [[ -f "build.gradle" ]]; then
        echo "gradle"
    else
        # Check if we're in a new project scenario (no src directory)
        if [[ ! -d "src" ]]; then
            echo "maven"
            print_info "Assuming Maven build tool for new project"
        fi
        echo "unknown"
    fi
}

detect_java_version_maven() {
    if [[ ! -f "pom.xml" ]]; then
        return 1
    fi

    # Pattern 1: <java.version>17</java.version>
    local version=$(grep -Eo '<java\.version>[0-9]+</java\.version>' pom.xml 2>/dev/null | grep -Eo '[0-9]+' | head -1)

    # Pattern 2: <maven.compiler.source>17</maven.compiler.source>
    if [[ -z "$version" ]]; then
        version=$(grep -Eo '<maven\.compiler\.source>[0-9]+</maven\.compiler\.source>' pom.xml 2>/dev/null | grep -Eo '[0-9]+' | head -1)
    fi

    # Pattern 3: <maven.compiler.target>17</maven.compiler.target>
    if [[ -z "$version" ]]; then
        version=$(grep -Eo '<maven\.compiler\.target>[0-9]+</maven\.compiler\.target>' pom.xml 2>/dev/null | grep -Eo '[0-9]+' | head -1)
    fi

    echo "$version"
}

detect_java_version_gradle() {
    local gradle_file=""

    # Check for Kotlin DSL first, then Groovy
    if [[ -f "build.gradle.kts" ]]; then
        gradle_file="build.gradle.kts"
    elif [[ -f "build.gradle" ]]; then
        gradle_file="build.gradle"
    else
        return 1
    fi

    # Pattern 1: JavaVersion.VERSION_17
    local version=$(grep -oP 'JavaVersion\.VERSION_\K[0-9]+' "$gradle_file" 2>/dev/null | head -1)

    # Pattern 2: sourceCompatibility = '17' or = "17"
    if [[ -z "$version" ]]; then
        version=$(grep -oP 'sourceCompatibility\s*=\s*[\x27\x22]\K[0-9]+' "$gradle_file" 2>/dev/null | head -1)
    fi

    # Pattern 3: JavaLanguageVersion.of(17)
    if [[ -z "$version" ]]; then
        version=$(grep -oP 'JavaLanguageVersion\.of\(\K[0-9]+' "$gradle_file" 2>/dev/null | head -1)
    fi

    echo "$version"
}

detect_java_version() {
    local java_version=""
    local build_tool=$(detect_build_tool)

    case "$build_tool" in
        "maven")
            java_version=$(detect_java_version_maven)
            ;;
        "gradle")
            java_version=$(detect_java_version_gradle)
            ;;
        *)
            print_warning "Could not detect build tool"
            ;;
    esac

    # Validate detected version
    if [[ -n "$java_version" ]] && validate_java_version "$java_version"; then
        print_success "Detected Java version: $java_version"
        echo "$java_version"
    else
        print_warning "Could not auto-detect Java version: $java_version"
        prompt_java_version
    fi
}

# ============================================================================
# Remote Template Download Functions
# ============================================================================

download_template_file() {
    local template_name=$1
    local file_name=$2
    local dest_path=$3

    local file_url="${REPO_URL}/raw/${BRANCH}/setup/java/templates/${template_name}/${file_name}"

    print_info "Downloading: ${file_name}..."

    if curl -sL --fail "$file_url" -o "$dest_path" 2>/dev/null; then
        print_success "Downloaded: ${file_name}"
        return 0
    else
        return 1
    fi
}

download_template() {
    local template_name=$1

    print_step "5a" "Downloading template files from GitHub"
    print_info "Branch: ${BRANCH}"
    print_info "Template: ${template_name}"
    echo ""

    # Create temporary directory structure
    TEMP_DIR=$(mktemp -d -t otel-templates.XXXXXX)
    CLEANUP_REQUIRED=true

    local template_dest="${TEMP_DIR}/${template_name}"
    mkdir -p "$template_dest"

    # Download each template file with fail-fast behavior
    local downloaded=0
    for file in "${TEMPLATE_FILES[@]}"; do
        local dest_file="${template_dest}/${file}"

        if download_template_file "$template_name" "$file" "$dest_file"; then
            ((downloaded++))
        else
            print_error "Failed to download: ${file} from branch '${BRANCH}'" false
            print_error "Template download failed - aborting" true
        fi
    done

    print_success "Downloaded ${downloaded}/${#TEMPLATE_FILES[@]} files successfully"

    # Update TEMPLATE_DIR to point to temp directory
    TEMPLATE_DIR="$TEMP_DIR"

    return 0
}

cleanup_temp_directory() {
    if [[ "$CLEANUP_REQUIRED" == true ]] && [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        print_info "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
        print_success "Cleanup complete"
    fi
}

# ============================================================================
# User Interaction Functions
# ============================================================================

prompt_yes_no() {
    local question="$1"
    local default="${2:-}"

    local prompt_suffix=""
    if [[ "$default" == "y" ]]; then
        prompt_suffix="[Y/n]"
    elif [[ "$default" == "n" ]]; then
        prompt_suffix="[y/N]"
    else
        prompt_suffix="[y/n]"
    fi

    while true; do
        read -p "$(echo -e ${CYAN}$question ${NC}$prompt_suffix: )" -r response

        # Handle default
        if [[ -z "$response" ]] && [[ -n "$default" ]]; then
            response="$default"
        fi

        case "$response" in
            y|Y|yes|Yes|YES) return 0 ;;
            n|N|no|No|NO) return 1 ;;
            *) print_warning "Please answer yes or no (y/n)" ;;
        esac
    done
}

prompt_java_version() {
    while true; do
        echo -e "${CYAN}Please specify Java version (17, 21, or 25):${NC}" >&2
        read -p "> " -r version

        if validate_java_version "$version"; then
            echo "$version"
            return 0
        else
            print_warning "Unsupported Java version: $version. Supported versions: ${SUPPORTED_JAVA_VERSIONS[*]}"
        fi
    done
}

prompt_with_default() {
    local prompt_text="$1"
    local default_value="$2"

    read -p "$(echo -e ${CYAN}${prompt_text} ${NC}[${default_value}]: )" -r response

    # Handle default
    if [[ -z "$response" ]]; then
        echo "$default_value"
    else
        echo "$response"
    fi
}

prompt_package_name() {
    local prompt_text="$1"
    local default_value="$2"

    while true; do
        read -p "$(echo -e ${CYAN}${prompt_text} ${NC}[${default_value}]: )" -r response

        # Handle default
        if [[ -z "$response" ]]; then
            response="$default_value"
        fi

        # Validate
        if validate_package_name "$response"; then
            echo "$response"
            return 0
        else
            print_warning "Invalid package name format. Use lowercase letters, numbers, dots, and hyphens."
        fi
    done
}

prompt_dependencies() {
    local base_deps="actuator,prometheus"

    print_info "Base dependencies (always included): actuator, prometheus" >&2

    if prompt_yes_no "Do you want to add additional dependencies?" "y"; then
        echo "" >&2
        print_info "Enter comma-separated dependency IDs (e.g., web,jpa,lombok)" >&2
        print_info "Run 'spring init --list' to see available dependencies" >&2
        read -p "$(echo -e ${CYAN}Additional dependencies: ${NC})" -r additional_deps

        if [[ -n "$additional_deps" ]]; then
            echo "${base_deps},${additional_deps}"
        else
            echo "$base_deps"
        fi
    else
        echo "$base_deps"
    fi
}

prompt_overwrite() {
    local filename="$1"

    while true; do
        echo -e "${YELLOW}File '$filename' already exists. Overwrite?${NC}" >&2
        echo -e "  ${CYAN}[y]${NC}es - overwrite this file" >&2
        echo -e "  ${CYAN}[n]${NC}o  - skip this file" >&2
        echo -e "  ${CYAN}[a]${NC}ll - overwrite all remaining files without prompting" >&2
        read -p "Your choice [y/n/a]: " -n 1 -r choice
        echo "" >&2

        case "$choice" in
            y|Y) echo "yes"; return 0 ;;
            n|N) echo "no"; return 0 ;;
            a|A) echo "all"; return 0 ;;
            *) print_warning "Invalid choice. Please enter y, n, or a." ;;
        esac
    done
}

# ============================================================================
# File Operations Functions
# ============================================================================

copy_file() {
    local source="$1"
    local dest="$2"
    local description="$3"

    # Dry run mode
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would copy: $description → $dest"
        return 0
    fi

    # Ensure destination directory exists
    local dest_dir=$(dirname "$dest")
    if [[ ! -d "$dest_dir" ]]; then
        mkdir -p "$dest_dir" 2>/dev/null || {
            print_error "Cannot create directory: $dest_dir" false
            return 1
        }
    fi

    # Attempt copy
    if cp "$source" "$dest" 2>/dev/null; then
        print_success "Copied: $description → $dest"
        return 0
    else
        print_error "Failed to copy: $dest (permission denied?)" false
        return 1
    fi
}

copy_configuration_files() {
    local template_dir="$1"
    local is_new_project="${2:-false}"
    local overwrite_all=false

    print_step "6" "Copying configuration files"

    # For new projects, always overwrite without prompting
    if [[ "$is_new_project" == true ]]; then
        overwrite_all=true
        print_info "New project mode: all configuration files will be overwritten"
    fi

    # Define file mappings: "source:destination:description"
    local file_mappings=(
        "Dockerfile:./Dockerfile:Container build configuration"
        "docker-compose.yaml:./docker-compose.yaml:Service orchestration"
        "application.properties:./src/main/resources/application.properties:Spring configuration"
        "logback-spring.xml:./src/main/resources/logback-spring.xml:Logging configuration"
    )

    for mapping in "${file_mappings[@]}"; do
        IFS=':' read -r source dest description <<< "$mapping"

        local source_path="${TEMPLATE_DIR}/${template_dir}/${source}"

        # Check if source exists
        if [[ ! -f "$source_path" ]]; then
            print_warning "Template file not found: $source_path"
            ((FILES_FAILED++))
            continue
        fi

        # Handle conflicts
        if [[ -f "$dest" ]] && [[ "$overwrite_all" != true ]]; then
            local response=$(prompt_overwrite "$dest")
            case "$response" in
                "yes")
                    if copy_file "$source_path" "$dest" "$description"; then
                        ((FILES_COPIED++))
                    else
                        ((FILES_FAILED++))
                    fi
                    ;;
                "all")
                    overwrite_all=true
                    if copy_file "$source_path" "$dest" "$description"; then
                        ((FILES_COPIED++))
                    else
                        ((FILES_FAILED++))
                    fi
                    ;;
                "no")
                    print_info "Skipped: $dest"
                    ((FILES_SKIPPED++))
                    ;;
            esac
        else
            # File doesn't exist or overwrite_all is true (including new projects)
            if copy_file "$source_path" "$dest" "$description"; then
                ((FILES_COPIED++))
            else
                ((FILES_FAILED++))
            fi
        fi
    done
}

create_environment_file() {
    local template_dir="$1"
    local is_new_project="${2:-false}"

    print_step "7" "Creating environment file"

    local env_example="${TEMPLATE_DIR}/${template_dir}/.env.example"
    local env_dest="./.env"

    # Check if .env.example exists in template
    if [[ ! -f "$env_example" ]]; then
        print_error "Template .env.example not found at: $env_example" true
    fi

    # Dry run mode
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would create .env from template"
        return 0
    fi

    if [[ -f "$env_dest" ]]; then
        # For new projects, always overwrite without prompting
        if [[ "$is_new_project" == true ]]; then
            cp "$env_example" "$env_dest"
            print_success "Created .env from template (new project mode)"
            print_info "Please review and update .env with your configuration"
            return 0
        else
            print_warning ".env file already exists"
            if prompt_yes_no "Overwrite existing .env file?" "y"; then
                cp "$env_example" "$env_dest"
                print_success "Created .env from template"
                print_info "Please review and update .env with your configuration"
                return 0
            else
                print_info "Kept existing .env file"
                return 1
            fi
        fi
    else
        cp "$env_example" "$env_dest"
        print_success "Created .env from .env.example"
        print_info "Please review and update values as needed"
        return 0
    fi
}

# ============================================================================
# Main Workflow Functions
# ============================================================================

create_new_project() {
    print_step "2" "Configuring new Spring Boot project"

    echo ""
    print_info "Collecting Spring Boot project configuration..."
    print_info "Press Enter to accept default values shown in brackets"
    echo ""

    # === Project Identity ===
    print_info "--- Project Identity ---"
    local name=$(prompt_with_default "Project name" "demo")
    PROJECT_NAME="$name"
    local artifact_id=$(prompt_with_default "Artifact ID" "demo")
    local group_id=$(prompt_package_name "Group ID" "co.ravn")


    # === Technical Configuration ===
    echo ""
    print_info "--- Technical Configuration ---"

    local language=$(prompt_with_default "Programming language" "java")

    # Java version prompt with validation
    local java_version=""
    while true; do
        java_version=$(prompt_with_default "Java version (17, 21, or 25)" "17")
        if validate_java_version "$java_version"; then
            break
        else
            print_warning "Unsupported Java version: $java_version. Supported: ${SUPPORTED_JAVA_VERSIONS[*]}"
        fi
    done

    # Store in global for later template selection
    JAVA_VERSION="$java_version"

    local boot_version=$(prompt_with_default "Spring Boot version" "3.5.8")

    # === Build System ===
    echo ""
    print_info "--- Build System ---"
    local project_type=$(prompt_with_default "Build system" "maven-project")

    # === Packaging ===
    echo ""
    print_info "--- Packaging Configuration ---"
    local packaging=$(prompt_with_default "Packaging type" "jar")

    # Smart default for package name
    local default_package_name="${group_id}.${artifact_id}"
    local package_name=$(prompt_package_name "Package name" "$default_package_name")

    # === Dependencies ===
    echo ""
    print_info "--- Dependencies ---"
    local dependencies=$(prompt_dependencies)

    # === Project Metadata ===
    echo ""
    print_info "--- Project Metadata ---"
    local version=$(prompt_with_default "Version" "0.0.1-SNAPSHOT")
    local description=$(prompt_with_default "Description" "Demo project for Spring Boot with Instrumentation")

    # === Display Summary ===
    echo ""
    print_info "--- Configuration Summary ---"
    echo -e "  Name:              ${GREEN}${name}${NC}"
    echo -e "  Artifact ID:       ${GREEN}${artifact_id}${NC}"
    echo -e "  Group ID:          ${GREEN}${group_id}${NC}"
    echo -e "  Language:          ${GREEN}${language}${NC}"
    echo -e "  Java Version:      ${GREEN}${java_version}${NC}"
    echo -e "  Spring Boot:       ${GREEN}${boot_version}${NC}"
    echo -e "  Build Type:        ${GREEN}${project_type}${NC}"
    echo -e "  Packaging:         ${GREEN}${packaging}${NC}"
    echo -e "  Package Name:      ${GREEN}${package_name}${NC}"
    echo -e "  Dependencies:      ${GREEN}${dependencies}${NC}"
    echo -e "  Version:           ${GREEN}${version}${NC}"
    echo -e "  Description:       ${GREEN}${description}${NC}"
    echo ""

    if ! prompt_yes_no "Proceed with project creation?" "y"; then
        print_error "Project creation cancelled by user" true
    fi

    # === Build Command ===
    local spring_init_cmd="spring init"
    spring_init_cmd+=" --group-id=${group_id}"
    spring_init_cmd+=" --artifact-id=${artifact_id}"
    spring_init_cmd+=" --name=${name}"
    spring_init_cmd+=" --description=\"${description}\""
    spring_init_cmd+=" --version=${version}"
    spring_init_cmd+=" --java-version=${java_version}"
    spring_init_cmd+=" --boot-version=${boot_version}"
    spring_init_cmd+=" --language=${language}"
    spring_init_cmd+=" --type=${project_type}"
    spring_init_cmd+=" --packaging=${packaging}"
    spring_init_cmd+=" --package-name=${package_name}"
    spring_init_cmd+=" --dependencies=${dependencies}"
    spring_init_cmd+=" --extract"

    # === Execute ===
    echo ""
    print_info "Executing: $spring_init_cmd"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would execute: $spring_init_cmd"
        return 0
    fi

    # Execute the command
    mkdir -p "$name"
    cd "$name" || {
        print_error "Failed to create and change to project directory: $name" true
    }
    if eval "$spring_init_cmd"; then
        print_success "Spring Boot project created successfully"
        return 0
    else
        print_error "Failed to create Spring Boot project. Check the error message above." true
    fi
}

display_summary() {
    local is_new_project="$1"
    local include_postgres="$2"

    echo ""
    print_header "Setup Complete!"

    echo -e "${GREEN}✅ Successfully configured OpenTelemetry instrumentation${NC}"
    echo ""

    # Display configuration summary
    echo -e "${CYAN}Configuration Summary:${NC}"
    echo -e "  • Java Version: ${GREEN}$JAVA_VERSION${NC}"
    echo -e "  • Template: ${GREEN}$SELECTED_TEMPLATE${NC}"
    echo -e "  • PostgreSQL: ${GREEN}$([ "$include_postgres" == true ] && echo "Yes" || echo "No")${NC}"
    echo ""

    # Files created/updated
    echo -e "${CYAN}Files Summary:${NC}"
    echo -e "  ${GREEN}✓${NC} Copied: $FILES_COPIED"
    if [[ $FILES_SKIPPED -gt 0 ]]; then
        echo -e "  ${YELLOW}⊘${NC} Skipped: $FILES_SKIPPED"
    fi
    if [[ $FILES_FAILED -gt 0 ]]; then
        echo -e "  ${RED}✗${NC} Failed: $FILES_FAILED"
    fi
    echo ""

    # Next steps
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "  ${BLUE}1.${NC} Go to your project directory: ${YELLOW}cd ${PROJECT_NAME}${NC}"
    echo -e "  ${BLUE}2.${NC} Review and update ${YELLOW}.env${NC} with your configuration"
    echo -e "  ${BLUE}3.${NC} Build and run: ${YELLOW}docker-compose up -d --build${NC}"
    echo -e "  ${BLUE}4.${NC} Access application: ${YELLOW}http://localhost:8080${NC}"
    echo -e "  ${BLUE}5.${NC} View metrics: ${YELLOW}http://localhost:8080/actuator/prometheus${NC}"

    if [[ "$include_postgres" == true ]]; then
        echo -e "  ${BLUE}5.${NC} PostgreSQL available: ${YELLOW}localhost:5432${NC}"
        echo -e "  ${BLUE}6.${NC} Postgres metrics: ${YELLOW}http://localhost:9187/metrics${NC}"
    fi

    echo ""

    # Display warnings if any
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Warnings encountered:${NC}"
        for warning in "${WARNINGS[@]}"; do
            echo -e "  ${YELLOW}•${NC} $warning"
        done
        echo ""
    fi

    # Display errors if any
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Errors encountered:${NC}"
        for error in "${ERRORS[@]}"; do
            echo -e "  ${RED}•${NC} $error"
        done
        echo ""
    fi

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============================================================================
# Argument Parsing and Help
# ============================================================================

show_help() {
    cat << EOF
Spring Boot OpenTelemetry Instrumentation Setup Script v${SCRIPT_VERSION}

USAGE:
    setup-otel.sh [OPTIONS]

OPTIONS:
    --help, -h         Show this help message
    --version, -v      Show script version
    --dry-run          Show what would be done without making changes
    --branch <name>    Specify Git branch for remote template download
                       (default: master)

DESCRIPTION:
    Automates the setup of Spring Boot applications with OpenTelemetry
    instrumentation. Supports both new and existing projects.

SUPPORTED JAVA VERSIONS:
    17, 21, 25

EXAMPLES:
    # Interactive setup
    ./setup-otel.sh

    # Dry run to see what would be done
    ./setup-otel.sh --dry-run

    # Use specific branch
    ./setup-otel.sh --branch java

REMOTE EXECUTION:
    # Execute directly from GitHub (default: master branch)
    bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/master/setup/java/setup-otel.sh)

    # Use different branch
    bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/java/setup/java/setup-otel.sh) --branch java

For more information, see: plan.md
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                print_info "DRY RUN MODE: No files will be modified"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "Spring Boot OpenTelemetry Setup Script v${SCRIPT_VERSION}"
                exit 0
                ;;
            --branch)
                if [[ -z "$2" ]]; then
                    print_error "Missing value for --branch flag" true
                fi
                BRANCH="$2"
                print_info "Using branch: $BRANCH"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1" false
                show_help
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    # Display welcome header
    print_header "Spring Boot OpenTelemetry Instrumentation Setup"

    # Parse command-line arguments
    parse_arguments "$@"

    # Step 1: Determine setup mode
    print_step "1" "Determine setup mode"
    local is_new_project=false
    if prompt_yes_no "Are you starting a new project?" "y"; then
        is_new_project=true
    fi

    # Step 2: Create new project if needed
    if [[ "$is_new_project" == true ]]; then
        print_step "2" "Creating new Spring Boot project"
        validate_spring_cli
        create_new_project
    fi

    # Step 3: Detect Java version
    print_step "3" "Detecting Java version"
    if [[ "$is_new_project" == true ]]; then
        # Java version already set by create_new_project()
        print_success "Using Java version from project configuration: $JAVA_VERSION"
    else
        # Detect from existing project files
        JAVA_VERSION=$(detect_java_version)
    fi

    # Validate that we have a Java version
    if [[ -z "$JAVA_VERSION" ]]; then
        print_error "Failed to determine Java version" true
    fi

    # Step 4: Determine PostgreSQL requirement
    print_step "4" "Database configuration"
    local include_postgres=false
    if prompt_yes_no "Do you want to include PostgreSQL database configuration?" "y"; then
        include_postgres=true
    fi

    # Step 5: Select and download template
    print_step "5" "Selecting and downloading template"
    local template_suffix=""
    [[ "$include_postgres" == true ]] && template_suffix="-postgres"
    SELECTED_TEMPLATE="java-${JAVA_VERSION}${template_suffix}"
    print_success "Selected template: $SELECTED_TEMPLATE"

    # Always download templates from GitHub
    download_template "$SELECTED_TEMPLATE"

    # Validate template exists after download
    if [[ ! -d "${TEMPLATE_DIR}/${SELECTED_TEMPLATE}" ]]; then
        print_error "Template directory not found after download: ${TEMPLATE_DIR}/${SELECTED_TEMPLATE}" true
    fi

    print_success "Template ready: $SELECTED_TEMPLATE"

    # Validate project structure
    validate_project_structure

    # Step 6: Copy configuration files
    copy_configuration_files "$SELECTED_TEMPLATE" "$is_new_project"

    # Step 7: Create environment file
    create_environment_file "$SELECTED_TEMPLATE" "$is_new_project"

    # Final: Display summary
    display_summary "$is_new_project" "$include_postgres"

    # Exit with appropriate code
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# ============================================================================
# Script Entry Point
# ============================================================================

# Trap for cleanup and unexpected errors
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        print_error "Unexpected error occurred" false
    fi
    cleanup_temp_directory
    exit $exit_code
}

trap cleanup EXIT ERR

# Execute main function
main "$@"
