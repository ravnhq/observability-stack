#!/bin/bash

# RAVN Observability Stack Installer
# Usage: curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/master/install.sh | bash -s -- [OPTIONS]
# Options:
#   --force          Force installation (overwrite existing)
#   --branch <name>  Specify branch to install from (default: master)
# Examples:
#   curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/master/install.sh | bash -s --
#   curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/master/install.sh | bash -s -- --branch develop
#   curl -sSL https://raw.githubusercontent.com/ravnhq/observability-stack/master/install.sh | bash -s -- --force --branch java

set -e

# Configuration
REPO_URL="https://github.com/ravnhq/observability-stack"
REPO_API="https://api.github.com/repos/ravnhq/observability-stack"
INSTALL_DIR="observability"
FORCE_INSTALL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_INSTALL=true
            shift
            ;;
        --branch)
            if [[ -z "$2" ]]; then
                echo -e "${RED}Error: Missing value for --branch flag${NC}"
                echo ""
                echo "Usage: bash -s -- [OPTIONS]"
                echo "Options:"
                echo "  --force          Force installation (overwrite existing)"
                echo "  --branch <name>  Specify branch to install from (default: master)"
                echo ""
                echo "Examples:"
                echo "  bash -s -- --branch develop"
                echo "  bash -s -- --force --branch java"
                exit 1
            fi
            BRANCH="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Error: Unknown argument: $1${NC}"
            echo ""
            echo "Usage: bash -s -- [OPTIONS]"
            echo "Options:"
            echo "  --force          Force installation (overwrite existing)"
            echo "  --branch <name>  Specify branch to install from (default: master)"
            echo ""
            echo "Examples:"
            echo "  bash -s --                        # Install from master branch"
            echo "  bash -s -- --branch develop       # Install from develop branch"
            echo "  bash -s -- --force --branch java  # Force install from java branch"
            exit 1
            ;;
    esac
done

BRANCH="${BRANCH:-master}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════╗"
    echo "║     RAVN Observability Stack Installer     ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_status() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    
    for cmd in docker docker-compose curl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install:"
        
        if [[ " ${missing_deps[@]} " =~ " docker " ]]; then
            echo "  • Docker: https://docs.docker.com/get-docker/"
        fi
        
        if [[ " ${missing_deps[@]} " =~ " docker-compose " ]]; then
            echo "  • Docker Compose: https://docs.docker.com/compose/install/"
        fi
        
        exit 1
    fi
    
    print_success "All dependencies found"
}

# Check if directory exists
check_existing_installation() {
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Directory '$INSTALL_DIR' already exists"
        
        if [ "$FORCE_INSTALL" = true ]; then
            print_status "Force flag set, overwriting..."
            rm -rf "$INSTALL_DIR"
            return
        fi
        
        # Check if we're running interactively
        if [ -t 0 ]; then
            read -p "Overwrite? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_status "Installation cancelled"
                exit 0
            fi
            rm -rf "$INSTALL_DIR"
        else
            print_error "Cannot prompt for confirmation in non-interactive mode"
            echo "  Use: curl -sSL ... | bash -s -- --force"
            echo "  Or:  curl -sSL ... | bash -s -- --force --branch <branch>"
            exit 1
        fi
    fi
}

# Download a file from the repository
download_file() {
    local file_path=$1
    local dest_path=$2
    local file_url="${REPO_URL}/raw/${BRANCH}/src/${file_path}"
    
    mkdir -p "$(dirname "$dest_path")"
    
    if curl -sL --fail "$file_url" -o "$dest_path" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Get list of files in src directory from GitHub API
get_src_files() {
    local api_url="${REPO_API}/contents/src?ref=${BRANCH}"
    curl -sL "$api_url" 2>/dev/null | grep '"path"' | sed 's/.*"path": "src\/\([^"]*\)".*/\1/' || true
}

# Download all files from src directory
download_src() {
    print_status "Downloading observability stack..."
    
    mkdir -p "$INSTALL_DIR"
    
    # List of essential files to download
    local files=(
        "docker-compose.yml"
        ".env.example"
        "config/alloy.alloy"
        "config/grafana.ini"
        "config/loki.yaml"
        "config/mimir.yaml"
        "config/mimir-runtime.yaml"
        "config/tempo.yaml"
        "grafana/provisioning/alerting/node-exporter-rules.yaml"
        "grafana/provisioning/datasources/datasources.yaml"
        "grafana/provisioning/dashboards/dashboards.yaml"
        "grafana/dashboards/spring-boot-dashboard.json"
    )
    
    local downloaded=0
    local failed=0
    
    for file in "${files[@]}"; do
        if download_file "$file" "$INSTALL_DIR/$file"; then
            ((downloaded++))
        else
            ((failed++))
            print_warning "Could not download: $file"
        fi
    done
    
    if [ $downloaded -eq 0 ]; then
        print_error "Failed to download any files"
        rm -rf "$INSTALL_DIR"
        exit 1
    fi
    
    print_success "Downloaded $downloaded files"
}

# Setup environment
setup_environment() {
    cd "$INSTALL_DIR"
    
    # Create .env from template
    if [ -f ".env.example" ]; then
        cp .env.example .env
        
        # Generate secure Grafana password
        if command -v openssl &> /dev/null; then
            local password=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/changeme_admin_password/$password/" .env
            else
                sed -i "s/changeme_admin_password/$password/" .env
            fi
            GRAFANA_PASSWORD=$password
            print_success "Generated secure Grafana password"
        else
            print_warning "Please change the default Grafana password in .env"
            GRAFANA_PASSWORD="changeme_admin_password"
        fi
    fi
    
    cd ..
}


# Print completion message
print_completion() {
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}         Installation Complete!${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════${NC}"
    echo ""
    echo "📁 Installation: ./$INSTALL_DIR/"
    if [ ! -z "$GRAFANA_PASSWORD" ]; then
        echo "🔑 Grafana Password: $GRAFANA_PASSWORD"
    fi
    echo ""
    echo "Next steps:"
    echo "  1. Start the stack:    cd $INSTALL_DIR && docker-compose up -d"
    echo "  2. Access Grafana:     http://localhost:3030 (admin/$GRAFANA_PASSWORD)"
    echo "  3. Configure your app to send telemetry to localhost:4317 (GRPC) or localhost:4318 (HTTP)"
    echo "  4. Customize settings in $INSTALL_DIR/.env"
    echo ""
    echo "Commands:"
    echo "  • Start:   cd $INSTALL_DIR && docker-compose up -d"
    echo "  • Stop:    cd $INSTALL_DIR && docker-compose down"
    echo "  • Logs:    cd $INSTALL_DIR && docker-compose logs -f"
    echo ""
    echo "📚 Documentation: https://github.com/ravnhq/observability-stack"
}

# Main installation
main() {
    print_header
    
    print_status "Checking dependencies..."
    check_dependencies
    echo ""
    
    check_existing_installation
    
    download_src
    echo ""
    
    print_status "Setting up environment..."
    setup_environment
    
    print_completion
}

# Run main function
main "$@"
