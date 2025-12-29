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
BRANCH="master"

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
    local auto_install=false

    # Check if running non-interactively (EC2 user data)
    if [ ! -t 0 ] || [ "$FORCE_INSTALL" = true ]; then
        auto_install=true
    fi

    # Check curl first (required for installation)
    if ! command -v curl &> /dev/null; then
        if [ "$auto_install" = true ]; then
            print_status "Installing curl..."
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case $ID in
                    amzn)
                        sudo yum install -y curl 2>/dev/null || sudo dnf install -y curl
                        ;;
                    ubuntu|debian)
                        sudo apt-get update && sudo apt-get install -y curl
                        ;;
                    *)
                        print_error "Cannot auto-install curl"
                        exit 1
                        ;;
                esac
            fi
        else
            print_error "curl is required but not installed"
            exit 1
        fi
    fi

    # Check for Docker and Docker Compose
    for cmd in docker docker-compose; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        if [ "$auto_install" = true ]; then
            print_warning "Missing dependencies: ${missing_deps[*]}"
            install_docker || exit 1
        else
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
    else
        print_success "All dependencies found"
    fi
}

# Install Docker and Docker Compose
install_docker() {
    print_status "Installing Docker and Docker Compose..."

    # Detect OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
    else
        print_error "Cannot detect OS version"
        return 1
    fi

    case $OS in
        amzn)
            # Amazon Linux 2 or AL2023
            if [[ "$VERSION_ID" == "2023" ]]; then
                # Amazon Linux 2023
                sudo dnf update -y
                sudo dnf install -y docker
            else
                # Amazon Linux 2
                sudo yum update -y
                sudo yum install -y docker
            fi

            # Install Docker Compose
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            ;;

        ubuntu|debian)
            sudo apt-get update -y
            sudo apt-get install -y docker.io docker-compose curl
            ;;

        centos|rhel|fedora)
            sudo dnf update -y
            sudo dnf install -y docker docker-compose curl
            ;;

        *)
            print_error "Unsupported OS: $OS"
            print_warning "Please install Docker manually: https://docs.docker.com/get-docker/"
            return 1
            ;;
    esac

    # Start Docker daemon
    sudo systemctl start docker
    sudo systemctl enable docker

    # Add current user to docker group (optional, for non-root usage)
    if [ -n "$SUDO_USER" ]; then
        sudo usermod -aG docker "$SUDO_USER"
        print_success "Added $SUDO_USER to docker group"
    fi

    # Verify Docker is running
    if ! sudo systemctl is-active --quiet docker; then
        print_error "Docker failed to start"
        return 1
    fi

    print_success "Docker and Docker Compose installed successfully"
    return 0
}

# Detect EC2 environment and get metadata
detect_ec2_environment() {
    print_status "Detecting environment..."

    # Check if running on EC2 using IMDSv2
    local token=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
        --connect-timeout 2 2>/dev/null)

    if [ -z "$token" ]; then
        print_status "Not running on EC2 (using localhost)"
        IS_EC2=false
        return 0
    fi

    IS_EC2=true
    print_success "EC2 environment detected"

    # Get instance details for logging
    EC2_INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $token" \
        http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
    EC2_AVAILABILITY_ZONE=$(curl -s -H "X-aws-ec2-metadata-token: $token" \
        http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null)

    print_status "Instance ID: $EC2_INSTANCE_ID"
    print_status "Availability Zone: $EC2_AVAILABILITY_ZONE"
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

    mkdir -p "$(dirname "$dest_path")" 2>/dev/null || true

    local curl_error
    if curl_error=$(curl -sL --fail "$file_url" -o "$dest_path" 2>&1); then
        return 0
    else
        if [ -n "$curl_error" ]; then
            echo "curl error: $curl_error" >&2
        fi
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
    print_status "Repository: $REPO_URL"
    print_status "Branch: $BRANCH"

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
        "grafana/provisioning/alerting/grafana-rules.yaml"
        "grafana/provisioning/alerting/contact-points.yaml"
        "grafana/provisioning/datasources/datasources.yaml"
        "grafana/provisioning/dashboards/dashboards.yaml"
        "grafana/dashboards/red-dashboard.json"
        "grafana/dashboards/use-dashboard.json"
    )
    
    local downloaded=0
    local failed=0
    local expected_files=${#files[@]}

    # Temporarily disable exit-on-error for downloads
    set +e

    for file in "${files[@]}"; do
        if download_file "$file" "$INSTALL_DIR/$file"; then
            ((downloaded++))
        else
            ((failed++))
            print_warning "Could not download: $file (from branch: $BRANCH)"
            if [ $failed -eq 1 ]; then
                print_status "Attempted URL: ${REPO_URL}/raw/${BRANCH}/src/${file}"
            fi
        fi
    done

    # Re-enable exit-on-error
    set -e

    if [ $downloaded -eq 0 ]; then
        print_error "Failed to download any files"
        rm -rf "$INSTALL_DIR"
        exit 1
    elif [ $downloaded -lt $expected_files ]; then
        print_error "Incomplete download: $downloaded/$expected_files files downloaded"
        print_warning "Missing $((expected_files - downloaded)) files"
        print_status "Check your network connection or try specifying a different branch"
        rm -rf "$INSTALL_DIR"
        exit 1
    fi

    print_success "Downloaded $downloaded/$expected_files files"
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

# Setup data directories with correct permissions for Linux
setup_data_directories() {
    print_status "Setting up data directories with correct permissions..."

    cd "$INSTALL_DIR"

    # Create data directories if they don't exist
    mkdir -p data/mimir data/loki data/tempo data/grafana

    # Detect if running on Linux (need to set ownership)
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_status "Linux detected - setting directory ownership..."

        # Check if we need sudo for chown
        if [ "$(id -u)" -ne 0 ]; then
            local use_sudo="sudo"
        else
            local use_sudo=""
        fi

        # Set ownership for each service
        $use_sudo chown -R 10001:10001 data/loki data/tempo || print_warning "Failed to set ownership for Loki/Tempo directories"
        $use_sudo chown -R 472:472 data/grafana || print_warning "Failed to set ownership for Grafana directory"

        print_success "Data directory permissions configured for Linux"
    else
        print_success "Data directories created (macOS - no ownership changes needed)"
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

    # Installation details
    echo "📁 Installation: ./$INSTALL_DIR/"
    if [ ! -z "$GRAFANA_PASSWORD" ]; then
        echo "🔑 Grafana Credentials: admin / $GRAFANA_PASSWORD"
    fi

    # Environment-specific information
    if [ "$IS_EC2" = true ]; then
        echo ""
        echo -e "${BLUE}EC2 Environment Detected${NC}"
        echo "  Instance ID: $EC2_INSTANCE_ID"
        echo "  Availability Zone: $EC2_AVAILABILITY_ZONE"
    fi

    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT - Next Steps Required${NC}"
    echo ""
    echo "  1. Configure .env with your AWS settings:"
    echo "     cd $INSTALL_DIR && nano .env"
    echo ""
    echo "  2. Start the observability stack:"
    echo "     cd $INSTALL_DIR && docker-compose up -d"
    echo ""
    echo "  3. Verify services are running:"
    echo "     cd $INSTALL_DIR && docker-compose ps"

    echo ""
    echo "🌐 Access URLs (after starting containers):"
    echo "  • Grafana:     http://localhost:3030"
    echo "  • Alloy UI:    http://localhost:12345"

    echo ""
    echo "📊 Send telemetry to:"
    echo "  • OTLP gRPC:   localhost:4317"
    echo "  • OTLP HTTP:   http://localhost:4318"

    echo ""
    echo "🔧 Management Commands:"
    echo "  • Start stack:  cd $INSTALL_DIR && docker-compose up -d"
    echo "  • View logs:    cd $INSTALL_DIR && docker-compose logs -f"
    echo "  • Stop stack:   cd $INSTALL_DIR && docker-compose down"
    echo "  • Restart:      cd $INSTALL_DIR && docker-compose restart"
    echo "  • View status:  cd $INSTALL_DIR && docker-compose ps"

    echo ""
    echo "📚 Documentation: https://github.com/ravnhq/observability-stack"
    echo ""
}

# Main installation
main() {
    # Global variables
    IS_EC2=false
    EC2_INSTANCE_ID=""
    EC2_AVAILABILITY_ZONE=""
    GRAFANA_PASSWORD=""

    print_header

    print_status "Checking dependencies..."
    check_dependencies
    echo ""

    detect_ec2_environment
    echo ""

    check_existing_installation

    download_src
    echo ""

    print_status "Setting up environment..."
    setup_environment
    echo ""

    setup_data_directories
    echo ""

    print_completion
}

# Run main function
main "$@"
