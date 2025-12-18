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
JAVA_VERSION=""
SELECTED_TEMPLATE=""
DRY_RUN=false
STRATEGY="overwrite"  # Default strategy: overwrite or patch

# File copy statistics
FILES_COPIED=0
FILES_SKIPPED=0
FILES_FAILED=0
FILES_PATCHED=0  # Track patched files in patch mode

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

validate_spring_boot_project() {
    print_info "Validating Spring Boot project..."

    if [[ ! -f "pom.xml" ]] && [[ ! -f "build.gradle" ]] && [[ ! -f "build.gradle.kts" ]]; then
        print_error "Not a Spring Boot project directory. No build file found (pom.xml, build.gradle, or build.gradle.kts)" true
    fi

    if [[ ! -d "src" ]]; then
        print_error "Invalid Spring Boot project structure. No 'src' directory found." true
    fi

    print_success "Valid Spring Boot project detected"
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

    local file_url="${REPO_URL}/raw/${BRANCH}/src/setup/java/templates/${template_name}/${file_name}"

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
            ((downloaded++)) || true
        else
            print_error "Failed to download: ${file} from branch '${BRANCH}'" false
            print_error "Template download failed - aborting" true
        fi
    done

    print_success "Downloaded ${downloaded}/${#TEMPLATE_FILES[@]} template files successfully"

    # Download patch files (for patch strategy support)
    local patch_dest="${template_dest}/patches"
    mkdir -p "$patch_dest"

    local patch_files=(
        "application.properties.patch"
        "application.yaml.patch"
        "logback-pattern.patch"
        ".env.example"
        "docker-compose-otel.yaml"
    )

    local patches_downloaded=0
    for patch_file in "${patch_files[@]}"; do
        local dest_file="${patch_dest}/${patch_file}"

        if download_template_file "$template_name/patches" "$patch_file" "$dest_file"; then
            ((patches_downloaded++)) || true
        else
            print_warning "Failed to download patch file: ${patch_file}"
        fi
    done

    if [[ $patches_downloaded -eq ${#patch_files[@]} ]]; then
        print_success "Downloaded ${patches_downloaded}/${#patch_files[@]} patch files successfully"
    else
        print_warning "Downloaded ${patches_downloaded}/${#patch_files[@]} patch files (some failed)"
        if [[ "$STRATEGY" == "patch" ]]; then
            print_warning "Patch mode may not work correctly without all patch files"
        fi
    fi

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

# ============================================================================
# Patch Mode Helper Functions
# ============================================================================

command_exists() {
    # Check if a command is available in the system
    # Args: $1 = command name
    # Returns: 0 if command exists, 1 otherwise
    command -v "$1" >/dev/null 2>&1
}

file_contains_marker() {
    # Check if a file already contains OTEL markers
    # Args: $1 = file path
    # Returns: 0 if markers found, 1 otherwise
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    grep -q "OTEL_CONFIG_START" "$file" 2>/dev/null
}

extract_patch_content() {
    # Extract content from a patch file
    # Args: $1 = patch file path
    # Returns: Prints the content, returns 0 on success, 1 on failure
    local patch_file="$1"

    if [[ ! -f "$patch_file" ]]; then
        print_error "Patch file not found: $patch_file" false
        return 1
    fi

    cat "$patch_file"
}

backup_file() {
    # Create a timestamped backup of a file
    # Args: $1 = file path
    # Returns: 0 on success, 1 on failure
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${file}.backup_${timestamp}"

    if cp "$file" "$backup_file" 2>/dev/null; then
        print_success "Created backup: $backup_file"
        return 0
    else
        print_warning "Failed to create backup for: $file"
        return 1
    fi
}

append_marked_block_if_missing() {
    # Append a marked block to a file if markers not present
    # Args: $1 = target file path, $2 = patch file path, $3 = description
    # Returns: 0 = success, 1 = skip (already patched), 2 = failure
    local target_file="$1"
    local patch_file="$2"
    local description="$3"

    # Check if already patched
    if file_contains_marker "$target_file"; then
        print_info "Already patched (markers found): $description"
        return 1
    fi

    # Dry run mode
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would append OTEL config to: $target_file"
        return 0
    fi

    # Create backup
    backup_file "$target_file"

    # Extract and append patch content
    local patch_content
    patch_content=$(extract_patch_content "$patch_file") || return 2

    # Ensure file ends with newline, then append
    if [[ -s "$target_file" ]] && [[ $(tail -c 1 "$target_file" | wc -l) -eq 0 ]]; then
        echo "" >> "$target_file"
    fi

    echo "" >> "$target_file"
    echo "$patch_content" >> "$target_file"

    if [[ $? -eq 0 ]]; then
        print_success "Patched: $description"
        return 0
    else
        print_error "Failed to patch: $description" false
        return 2
    fi
}

patch_logback_pattern() {
    # Modify existing CONSOLE appender pattern for trace correlation
    # Args: $1 = target file path, $2 = patch file path, $3 = description
    # Returns: 0 = success, 1 = skip, 2 = failure
    local target_file="$1"
    local patch_file="$2"
    local description="$3"

    # Check if already patched (look for trace_id in pattern)
    if grep -q "trace_id" "$target_file" 2>/dev/null; then
        print_info "Already patched (trace_id found): $description"
        return 1
    fi

    # Check if CONSOLE appender exists
    if ! grep -q '<appender name="CONSOLE"' "$target_file" 2>/dev/null; then
        print_warning "No CONSOLE appender found in $target_file - skipping"
        print_info "Manual action: Add trace_id and span_id to your logging pattern"
        return 2
    fi

    # Dry run mode
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would patch CONSOLE appender pattern in: $target_file"
        return 0
    fi

    # Create backup
    backup_file "$target_file"

    # Extract new pattern from patch file
    local new_pattern
    new_pattern=$(cat "$patch_file") || return 2

    # Create temp file for sed operation
    local temp_file="${target_file}.tmp"

    # Use awk to replace pattern within CONSOLE appender
    awk -v pattern="$new_pattern" '
    /<appender name="CONSOLE"/ { in_console=1; print; print "    <!-- OTEL_CONFIG: Trace correlation added by setup script -->"; next }
    in_console && /<pattern>/ { print "            <pattern>" pattern "</pattern>"; next }
    in_console && /<\/appender>/ { in_console=0 }
    { print }
    ' "$target_file" > "$temp_file"

    if [[ $? -eq 0 ]] && [[ -s "$temp_file" ]]; then
        mv "$temp_file" "$target_file"
        print_success "Patched: $description"
        return 0
    else
        rm -f "$temp_file"
        print_error "Failed to patch: $description" false
        return 2
    fi
}

merge_yaml_with_yq() {
    # Merge YAML using yq
    # Args: $1 = target file path, $2 = patch file path, $3 = description
    # Returns: 0 = success, 1 = skip, 2 = failure
    local target_file="$1"
    local patch_file="$2"
    local description="$3"

    # Check if already patched
    if file_contains_marker "$target_file"; then
        print_info "Already patched (markers found): $description"
        return 1
    fi

    # Check for yq
    if ! command_exists "yq"; then
        print_warning "yq not found. Cannot safely merge YAML: $target_file"
        print_info "Install yq (https://github.com/mikefarah/yq) or use --strategy overwrite"
        return 2
    fi

    # Dry run mode
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would merge OTEL config into: $target_file using yq"
        return 0
    fi

    # Create backup
    backup_file "$target_file"

    # Extract patch content (remove markers for yq merge)
    local patch_content_clean="${patch_file}.clean.tmp"
    sed '/OTEL_CONFIG_START/d; /OTEL_CONFIG_END/d' "$patch_file" > "$patch_content_clean"

    # Merge using yq
    local temp_file="${target_file}.tmp"
    yq eval-all '. as $item ireduce ({}; . * $item)' "$target_file" "$patch_content_clean" > "$temp_file" 2>/dev/null

    if [[ $? -eq 0 ]] && [[ -s "$temp_file" ]]; then
        mv "$temp_file" "$target_file"
        rm -f "$patch_content_clean"
        print_success "Merged (yq): $description"
        return 0
    else
        rm -f "$temp_file" "$patch_content_clean"
        print_error "Failed to merge YAML: $description" false
        return 2
    fi
}

merge_docker_compose_with_yq() {
    # Merge docker-compose.yaml using yq
    # Args: $1 = target file path, $2 = patch file path, $3 = description
    # Returns: 0 = success, 1 = skip, 2 = failure
    local target_file="$1"
    local patch_file="$2"
    local description="$3"

    # Check if already patched (look for node_exporter service as indicator)
    if grep -q "node_exporter:" "$target_file" 2>/dev/null && grep -q "extra_hosts:" "$target_file" 2>/dev/null; then
        print_info "Already patched (OTEL services detected): $description"
        return 1
    fi

    # Check for yq
    if ! command_exists "yq"; then
        print_warning "yq not found. Cannot safely merge docker-compose.yaml"
        print_info "Install yq (https://github.com/mikefarah/yq) or use --strategy overwrite"
        print_info "Manual action: Add OTEL services and environment variables"
        print_info "Reference template: ${patch_file}"
        return 2
    fi

    # Dry run mode
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would merge OTEL services into: $target_file using yq"
        return 0
    fi

    # Create backup
    backup_file "$target_file"

    # Use deep merge strategy with yq
    local temp_file="${target_file}.tmp"
    yq eval-all '. as $item ireduce ({}; . *+ $item)' "$target_file" "$patch_file" > "$temp_file" 2>/dev/null

    if [[ $? -eq 0 ]] && [[ -s "$temp_file" ]]; then
        mv "$temp_file" "$target_file"
        print_success "Merged (yq): $description"
        return 0
    else
        rm -f "$temp_file"
        print_error "Failed to merge docker-compose.yaml" false
        return 2
    fi
}

patch_configuration_files() {
    # Patch existing configuration files with OTEL-specific config
    # Args: $1 = template directory name
    local template_dir="$1"
    local patch_dir="${TEMPLATE_DIR}/${template_dir}/patches"

    print_step "4" "Patching configuration files (non-destructive)"
    print_info "This will insert only OTEL-specific configuration into your existing files"

    # Validate patch directory exists
    if [[ ! -d "$patch_dir" ]]; then
        print_error "Patch directory not found: $patch_dir" true
    fi

    # Define patch operations: "target_file:patch_file:description:patch_function"
    local -a operations=(
        "./src/main/resources/application.properties:${patch_dir}/application.properties.patch:Spring properties:append_marked_block_if_missing"
        "./src/main/resources/logback-spring.xml:${patch_dir}/logback-pattern.patch:Logging configuration:patch_logback_pattern"
        "./docker-compose.yaml:${patch_dir}/docker-compose-otel.yaml:Docker Compose:merge_docker_compose_with_yq"
    )

    # Handle application.yaml if it exists (check for both .yaml and .yml)
    if [[ -f "./src/main/resources/application.yaml" ]]; then
        operations+=("./src/main/resources/application.yaml:${patch_dir}/application.yaml.patch:Spring YAML:merge_yaml_with_yq")
    elif [[ -f "./src/main/resources/application.yml" ]]; then
        operations+=("./src/main/resources/application.yml:${patch_dir}/application.yaml.patch:Spring YAML:merge_yaml_with_yq")
    fi

    # Execute patch operations
    for op in "${operations[@]}"; do
        IFS=':' read -r target patch desc func <<< "$op"

        # Skip if target doesn't exist
        if [[ ! -f "$target" ]]; then
            print_info "Skipped: $target (file not found)"
            ((FILES_SKIPPED++)) || true
            continue
        fi

        # Check if patch file exists
        if [[ ! -f "$patch" ]]; then
            print_warning "Patch file not found: $patch"
            ((FILES_FAILED++)) || true
            continue
        fi

        # Execute the appropriate patch function
        local result=0
        $func "$target" "$patch" "$desc" || result=$?

        # Update counters based on result
        case $result in
            0) ((FILES_PATCHED++)) ;;
            1) ((FILES_SKIPPED++)) ;;
            2) ((FILES_FAILED++)) ;;
        esac
    done

    # Dockerfile - manual instructions
    if [[ -f "./Dockerfile" ]]; then
        print_info "Dockerfile detected - manual patching required"
        print_warning "Automated Dockerfile patching not supported for safety"
        echo ""
        echo -e "${CYAN}Manual Dockerfile steps:${NC}"
        echo -e "  ${BLUE}1.${NC} Add OTEL agent download stage:"
        echo -e "     ${YELLOW}FROM alpine:latest AS otel-agent"
        echo -e "     WORKDIR /otel"
        echo -e "     RUN apk add --no-cache curl && \\"
        echo -e "         curl -L -o opentelemetry-javaagent.jar \\"
        echo -e "         https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar${NC}"
        echo ""
        echo -e "  ${BLUE}2.${NC} Copy agent in runtime stage:"
        echo -e "     ${YELLOW}COPY --from=otel-agent /otel/opentelemetry-javaagent.jar otel-javaagent.jar${NC}"
        echo ""
        echo -e "  ${BLUE}3.${NC} Add javaagent to ENTRYPOINT/CMD:"
        echo -e "     ${YELLOW}java -javaagent:otel-javaagent.jar -jar app.jar${NC}"
        echo ""
        ((FILES_SKIPPED++)) || true
    else
        print_info "No Dockerfile found - you may need to create one with OTEL agent support"
    fi
}

copy_configuration_files() {
    local template_dir="$1"
    local overwrite_all=false

    print_step "4" "Copying configuration files"

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
            ((FILES_FAILED++)) || true
            continue
        fi

        # Handle conflicts
        if [[ -f "$dest" ]] && [[ "$overwrite_all" != true ]]; then
            local response=$(prompt_overwrite "$dest")
            case "$response" in
                "yes")
                    if copy_file "$source_path" "$dest" "$description"; then
                        ((FILES_COPIED++)) || true
                    else
                        ((FILES_FAILED++)) || true
                    fi
                    ;;
                "all")
                    overwrite_all=true
                    if copy_file "$source_path" "$dest" "$description"; then
                        ((FILES_COPIED++)) || true
                    else
                        ((FILES_FAILED++)) || true
                    fi
                    ;;
                "no")
                    print_info "Skipped: $dest"
                    ((FILES_SKIPPED++)) || true
                    ;;
            esac
        else
            # File doesn't exist or overwrite_all is true (including new projects)
            if copy_file "$source_path" "$dest" "$description"; then
                ((FILES_COPIED++)) || true
            else
                ((FILES_FAILED++)) || true
            fi
        fi
    done
}

create_environment_file() {
    local template_dir="$1"

    print_step "5" "Creating/patching environment file"

    local env_dest="./.env"

    # Check strategy mode
    if [[ "$STRATEGY" == "patch" ]]; then
        local patch_dir="${TEMPLATE_DIR}/${template_dir}/patches"
        local env_patch_example="${patch_dir}/.env.example"

        if [[ -f "$env_dest" ]]; then
            # Patch existing .env
            if [[ ! -f "$env_patch_example" ]]; then
                print_error "Patch file not found: $env_patch_example" false
                ((FILES_FAILED++)) || true
                return 1
            fi

            local result=0
            append_marked_block_if_missing "$env_dest" "$env_patch_example" "Environment file" || result=$?

            case $result in
                0)
                    ((FILES_PATCHED++))
                    print_info "Please review .env and update OTEL values as needed"
                    ;;
                1)
                    ((FILES_SKIPPED++))
                    ;;
                2)
                    ((FILES_FAILED++))
                    ;;
            esac
        else
            # .env doesn't exist, create from template
            local env_example="${TEMPLATE_DIR}/${template_dir}/.env.example"
            if [[ ! -f "$env_example" ]]; then
                print_error "Template .env.example not found: $env_example" true
            fi

            if [[ "$DRY_RUN" == true ]]; then
                print_info "[DRY RUN] Would create .env from template"
                return 0
            fi

            cp "$env_example" "$env_dest"
            ((FILES_PATCHED++)) || true
            print_success "Created .env from .env.example"
            print_info "Please review and update values as needed"
        fi
    else
        # Overwrite mode - keep existing behavior unchanged
        local env_example="${TEMPLATE_DIR}/${template_dir}/.env.example"

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
            print_warning ".env file already exists"
            if prompt_yes_no "Overwrite existing .env file?" "y"; then
                cp "$env_example" "$env_dest"
                print_success "Created .env from template"
                print_info "Please review and update .env with your configuration"
                return 0
            else
                print_info "Kept existing .env file"
                return 0
            fi
        else
            cp "$env_example" "$env_dest"
            print_success "Created .env from .env.example"
            print_info "Please review and update values as needed"
            return 0
        fi
    fi
}

# ============================================================================
# Main Workflow Functions
# ============================================================================

display_summary() {
    local include_postgres="$1"

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
    if [[ "$STRATEGY" == "patch" ]]; then
        echo -e "  ${GREEN}✓${NC} Patched: $FILES_PATCHED"
    else
        echo -e "  ${GREEN}✓${NC} Copied: $FILES_COPIED"
    fi
    if [[ $FILES_SKIPPED -gt 0 ]]; then
        echo -e "  ${YELLOW}⊘${NC} Skipped: $FILES_SKIPPED"
    fi
    if [[ $FILES_FAILED -gt 0 ]]; then
        echo -e "  ${RED}✗${NC} Failed: $FILES_FAILED"
    fi
    echo ""

    # Next steps
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "  ${BLUE}1.${NC} Review and update ${YELLOW}.env${NC} with your configuration"
    echo -e "  ${BLUE}2.${NC} Build and run: ${YELLOW}docker-compose up -d --build${NC}"
    echo -e "  ${BLUE}3.${NC} Access application: ${YELLOW}http://localhost:8080${NC}"
    echo -e "  ${BLUE}4.${NC} View metrics: ${YELLOW}http://localhost:8080/actuator/prometheus${NC}"

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
    --help, -h          Show this help message
    --version, -v       Show script version
    --dry-run           Show what would be done without making changes
    --strategy <mode>   File handling strategy (default: overwrite)
                        - overwrite: Replace entire files with templates
                        - patch: Insert only OTEL config into existing files
    --branch <name>     Specify Git branch for remote template download
                        (default: master)

DESCRIPTION:
    Automates the setup of OpenTelemetry instrumentation for existing
    Spring Boot applications. Detects Java version, downloads appropriate
    templates, and configures observability stack.

SUPPORTED JAVA VERSIONS:
    17, 21, 25

EXAMPLES:
    # Interactive setup (default: overwrite mode)
    ./setup-otel.sh

    # Use patch strategy to preserve existing config
    ./setup-otel.sh --strategy patch

    # Dry run to see what would be done
    ./setup-otel.sh --dry-run

    # Patch mode with dry run
    ./setup-otel.sh --strategy patch --dry-run

    # Use specific branch
    ./setup-otel.sh --branch java

REMOTE EXECUTION:
    # Execute directly from GitHub (default: master branch)
    bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/master/src/setup/java/setup-otel.sh)

    # Use different branch
    bash <(curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/java/src/setup/java/setup-otel.sh) --branch java

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
            --strategy)
                if [[ -z "$2" ]]; then
                    print_error "Missing value for --strategy flag" true
                fi
                if [[ "$2" != "overwrite" ]] && [[ "$2" != "patch" ]]; then
                    print_error "Invalid strategy: $2. Must be 'overwrite' or 'patch'" true
                fi
                STRATEGY="$2"
                print_info "Using strategy: $STRATEGY"
                shift 2
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

    # Step 0: Validate Spring Boot project
    print_step "0" "Validating project"
    validate_spring_boot_project

    # Step 1: Detect Java version
    print_step "1" "Detecting Java version"
    JAVA_VERSION=$(detect_java_version)

    # Validate that we have a Java version
    if [[ -z "$JAVA_VERSION" ]]; then
        print_error "Failed to determine Java version" true
    fi

    # Step 2: Determine PostgreSQL requirement
    print_step "2" "Database configuration"
    local include_postgres=false
    if prompt_yes_no "Do you want to include PostgreSQL database configuration?" "y"; then
        include_postgres=true
    fi

    # Step 3: Select and download template
    print_step "3" "Selecting and downloading template"
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

    # Step 4: Copy or patch configuration files based on strategy
    if [[ "$STRATEGY" == "patch" ]]; then
        patch_configuration_files "$SELECTED_TEMPLATE"
    else
        copy_configuration_files "$SELECTED_TEMPLATE"
    fi

    # Step 5: Create environment file
    create_environment_file "$SELECTED_TEMPLATE"

    # Final: Display summary
    display_summary "$include_postgres"

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
