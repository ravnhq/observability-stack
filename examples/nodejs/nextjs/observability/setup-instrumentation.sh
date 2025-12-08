#!/usr/bin/env bash
set -euo pipefail

DEFAULT_OTLP_URL="http://localhost:4318"
DEFAULT_SERVICE_NAME="nextjs-app"
DEFAULT_SERVICE_VERSION="1.0.0"

REQUIRED_PACKAGES=(
  "@opentelemetry/api"
  "@opentelemetry/sdk-node"
  "@opentelemetry/sdk-metrics"
  "@opentelemetry/sdk-logs"
  "@opentelemetry/sdk-trace-base"
  "@opentelemetry/resources"
  "@opentelemetry/semantic-conventions"
  "@opentelemetry/exporter-trace-otlp-http"
  "@opentelemetry/exporter-metrics-otlp-http"
  "@opentelemetry/exporter-logs-otlp-http"
  "@opentelemetry/exporter-trace-otlp-grpc"
  "@opentelemetry/exporter-logs-otlp-grpc"
  "@opentelemetry/exporter-metrics-otlp-grpc"
  "@opentelemetry/exporter-prometheus"
  "@opentelemetry/otlp-exporter-base"
  "@opentelemetry/otlp-grpc-exporter-base"
  "@opentelemetry/instrumentation"
  "@opentelemetry/instrumentation-pino"
  "@opentelemetry/instrumentation-http"
  "pino"
  "pino-pretty"
  "@grpc/grpc-js"
  "@grpc/proto-loader"
  "protobufjs"
  "@pyroscope/nodejs"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${PROJECT_ROOT}"
TEMPLATE_DIR="${SCRIPT_DIR}/templates/nextjs"
INSTRUMENTATION_FILE="${SRC_DIR}/instrumentation.ts"
NODE_OTEL_FILE="${SRC_DIR}/otel.ts"
NEXT_CONFIG_FILE="${PROJECT_ROOT}/next.config.ts"

if [ ! -f "${PROJECT_ROOT}/package.json" ]; then
  echo "❌ package.json not found in ${PROJECT_ROOT}"
  exit 1
fi

if [ ! -d "$SRC_DIR" ]; then
  echo "❌ Could not find project directory at $SRC_DIR"
  exit 1
fi

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "❌ Template directory not found at $TEMPLATE_DIR"
  exit 1
fi

ensure_dependencies() {
  pushd "$PROJECT_ROOT" >/dev/null
  local missing_packages=()

  for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! node -e "const pkg=require('./package.json'); const deps={...(pkg.dependencies||{}), ...(pkg.devDependencies||{})}; process.exit(deps['$pkg'] ? 0 : 1);" >/dev/null 2>&1; then
      missing_packages+=("$pkg")
    fi
  done

  if [ ${#missing_packages[@]} -gt 0 ]; then
    echo "📦 Installing missing telemetry dependencies: ${missing_packages[*]}"
    npm install "${missing_packages[@]}"
  else
    echo "✅ All telemetry dependencies are already installed"
  fi

  popd >/dev/null
}

read -r -p "Enter OTLP collector URL [${DEFAULT_OTLP_URL}]: " USER_OTLP_URL
OTLP_URL=${USER_OTLP_URL:-$DEFAULT_OTLP_URL}

read -r -p "Enter service / project name [${DEFAULT_SERVICE_NAME}]: " USER_SERVICE_NAME
SERVICE_NAME=${USER_SERVICE_NAME:-$DEFAULT_SERVICE_NAME}

read -r -p "Enter service version [${DEFAULT_SERVICE_VERSION}]: " USER_SERVICE_VERSION
SERVICE_VERSION=${USER_SERVICE_VERSION:-$DEFAULT_SERVICE_VERSION}

backup_file() {
  local target="$1"
  if [ -f "$target" ]; then
    cp "$target" "$target.bak"
    echo "📦 Backed up existing $(basename "$target") to $(basename "$target").bak"
  fi
}

copy_template() {
  local template_name="$1"
  local destination="$2"
  local template_path="$TEMPLATE_DIR/$template_name"

  if [ ! -f "$template_path" ]; then
    echo "❌ Missing template: $template_path"
    exit 1
  fi

  cp "$template_path" "$destination"
}

escape_sed() {
  printf '%s' "$1" | sed -e 's/[&/]/\\&/g'
}

replace_placeholder() {
  local file="$1"
  local placeholder="$2"
  local value="$3"
  local escaped
  escaped="$(escape_sed "$value")"
  sed -e "s|$placeholder|$escaped|g" "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}

echo "🛠️  Writing instrumentation files into $SRC_DIR"
backup_file "$INSTRUMENTATION_FILE"
backup_file "$NODE_OTEL_FILE"
backup_file "$NEXT_CONFIG_FILE"

ensure_dependencies

copy_template "instrumentation.ts.tpl" "$INSTRUMENTATION_FILE"
copy_template "otel.ts.tpl" "$NODE_OTEL_FILE"
copy_template "next.config.ts.tpl" "$NEXT_CONFIG_FILE"

replace_placeholder "$NODE_OTEL_FILE" '__DEFAULT_OTLP_URL__' "$OTLP_URL"
replace_placeholder "$NODE_OTEL_FILE" '__DEFAULT_SERVICE_NAME__' "$SERVICE_NAME"
replace_placeholder "$NODE_OTEL_FILE" '__DEFAULT_SERVICE_VERSION__' "$SERVICE_VERSION"

echo "✅ Generated files:"
echo "   - $(realpath "$INSTRUMENTATION_FILE")"
echo "   - $(realpath "$NODE_OTEL_FILE")"
echo "   - $(realpath "$NEXT_CONFIG_FILE")"

echo ""
echo "ℹ️  Runtime defaults"
echo "   OTEL_COLLECTOR_URL=${OTLP_URL}"
if [ -n "$SERVICE_NAME" ]; then
  echo "   SERVICE_NAME=${SERVICE_NAME}"
fi
echo "   SERVICE_VERSION=${SERVICE_VERSION}"

echo "You can override these values via environment variables when running Next.js or Docker Compose."
