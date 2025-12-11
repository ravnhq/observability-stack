#!/usr/bin/env bash
set -euo pipefail

DEFAULT_OTLP_URL="http://localhost:4318"
DEFAULT_SERVICE_VERSION="1.0.0"
DEFAULT_PYROSCOPE_URL="http://localhost:4040"

COMMON_PACKAGES=(
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
  "@opentelemetry/auto-instrumentations-node"
  "@opentelemetry/instrumentation"
  "@opentelemetry/instrumentation-http"
)

EXPRESS_PACKAGES=(
  "@opentelemetry/instrumentation-express"
  "@opentelemetry/instrumentation-pino"
  "@pyroscope/nodejs"
  "pino"
  "pino-pretty"
)

NEST_PACKAGES=(
  "@opentelemetry/instrumentation-express"
  "@opentelemetry/instrumentation-nestjs-core"
)

NEXT_PACKAGES=(
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
TEMPLATE_ROOT="${SCRIPT_DIR}/templates/lgtm"
PROJECT_ROOT="$PWD"
PACKAGE_JSON="${PROJECT_ROOT}/package.json"

if [ ! -f "$PACKAGE_JSON" ]; then
  echo "❌ package.json not found in ${PROJECT_ROOT}"
  exit 1
fi

if [ ! -d "$TEMPLATE_ROOT" ]; then
  echo "❌ Template directory not found at ${TEMPLATE_ROOT}"
  exit 1
fi

FRAMEWORK=""
FRAMEWORK_LABEL=""
SRC_DIR="${PROJECT_ROOT}/src"
ENTRY_FILE=""
DEFAULT_SERVICE_NAME=""
FRAMEWORK_PACKAGES=()
TEMPLATE_DIR=""
PYROSCOPE_URL="$DEFAULT_PYROSCOPE_URL"

select_framework() {
  while true; do
    echo "Select the framework to patch:"
    echo "  1) Express"
    echo "  2) NestJS"
    echo "  3) Next.js"
    read -r -p "Choice [1-3]: " choice
    case "${choice}" in
      1|"express"|"Express")
        FRAMEWORK="express"
        FRAMEWORK_LABEL="Express"
        ENTRY_FILE="${SRC_DIR}/server.ts"
        DEFAULT_SERVICE_NAME="express-app"
        FRAMEWORK_PACKAGES=("${EXPRESS_PACKAGES[@]}")
        TEMPLATE_DIR="${TEMPLATE_ROOT}/express"
        return
        ;;
      2|"nest"|"nestjs"|"NestJS")
        FRAMEWORK="nestjs"
        FRAMEWORK_LABEL="NestJS"
        ENTRY_FILE="${SRC_DIR}/main.ts"
        DEFAULT_SERVICE_NAME="nestjs-app"
        FRAMEWORK_PACKAGES=("${NEST_PACKAGES[@]}")
        TEMPLATE_DIR="${TEMPLATE_ROOT}/nestjs"
        return
        ;;
      3|"next"|"nextjs"|"NextJS"|"Next.js")
        FRAMEWORK="nextjs"
        FRAMEWORK_LABEL="Next.js"
        ENTRY_FILE=""
        DEFAULT_SERVICE_NAME="nextjs-app"
        FRAMEWORK_PACKAGES=("${NEXT_PACKAGES[@]}")
        TEMPLATE_DIR="${TEMPLATE_ROOT}/nextjs"
        return
        ;;
      *)
        echo "⚠️  Invalid choice. Please select 1, 2, or 3."
        ;;
    esac
  done
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

backup_file() {
  local target="$1"
  if [ -f "$target" ]; then
    cp "$target" "$target.bak"
    echo "📦 Backed up $(basename "$target") to $(basename "$target").bak"
  fi
}

ensure_dependencies() {
  pushd "$PROJECT_ROOT" >/dev/null
  local missing_packages=()

  for pkg in "$@"; do
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

prepend_block_if_missing() {
  local file="$1"
  local marker="$2"
  local block="$3"

  if grep -Fq "$marker" "$file"; then
    echo "ℹ️  Instrumentation bootstrap already present in $(basename "$file")"
    return
  fi

  local tmp
  tmp="$(mktemp)"
  {
    printf "%s\n\n" "$block"
    cat "$file"
  } > "$tmp"
  mv "$tmp" "$file"
  echo "✅ Added instrumentation bootstrap to $(basename "$file")"
}

select_framework

if [ "$FRAMEWORK" != "nextjs" ] && [ ! -d "$SRC_DIR" ]; then
  echo "❌ Could not find src/ directory in ${PROJECT_ROOT}"
  exit 1
fi

if [ -n "$ENTRY_FILE" ] && [ ! -f "$ENTRY_FILE" ]; then
  echo "❌ Entry file not found at $ENTRY_FILE"
  exit 1
fi

read -r -p "Enter OTLP collector URL [${DEFAULT_OTLP_URL}]: " USER_OTLP_URL
OTLP_URL=${USER_OTLP_URL:-$DEFAULT_OTLP_URL}

read -r -p "Enter service / project name [${DEFAULT_SERVICE_NAME}]: " USER_SERVICE_NAME
SERVICE_NAME=${USER_SERVICE_NAME:-$DEFAULT_SERVICE_NAME}

read -r -p "Enter service version [${DEFAULT_SERVICE_VERSION}]: " USER_SERVICE_VERSION
SERVICE_VERSION=${USER_SERVICE_VERSION:-$DEFAULT_SERVICE_VERSION}

if [ "$FRAMEWORK" = "express" ]; then
  read -r -p "Enter Pyroscope endpoint [${DEFAULT_PYROSCOPE_URL}]: " USER_PYRO_URL
  PYROSCOPE_URL=${USER_PYRO_URL:-$DEFAULT_PYROSCOPE_URL}
fi

if [ "$FRAMEWORK" = "nextjs" ]; then
  REQUIRED_PACKAGES=("${FRAMEWORK_PACKAGES[@]}")
else
  REQUIRED_PACKAGES=("${COMMON_PACKAGES[@]}" "${FRAMEWORK_PACKAGES[@]}")
fi
ensure_dependencies "${REQUIRED_PACKAGES[@]}"

EXPRESS_BOOTSTRAP="$(cat <<'EOF'
// Initialize OpenTelemetry before configuring the Express app
import { startInstrumentation } from './instrumentation';

startInstrumentation();
EOF
)"

NEST_BOOTSTRAP="$(cat <<'EOF'
// Initialize OpenTelemetry BEFORE importing anything else
import { startInstrumentation } from './instrumentation';

startInstrumentation();
EOF
)"

echo ""
echo "🛠️  Applying LGTM instrumentation for ${FRAMEWORK_LABEL}"

SUMMARY_LINES=()

if [ "$FRAMEWORK" = "express" ]; then
  INSTRUMENTATION_FILE="${SRC_DIR}/instrumentation.ts"
  backup_file "$INSTRUMENTATION_FILE"
  backup_file "$ENTRY_FILE"

  if [ ! -f "${TEMPLATE_DIR}/instrumentation.ts.tpl" ]; then
    echo "❌ Missing instrumentation template for ${FRAMEWORK}"
    exit 1
  fi

  cp "${TEMPLATE_DIR}/instrumentation.ts.tpl" "$INSTRUMENTATION_FILE"
  replace_placeholder "$INSTRUMENTATION_FILE" '__DEFAULT_OTLP_URL__' "$OTLP_URL"
  replace_placeholder "$INSTRUMENTATION_FILE" '__DEFAULT_SERVICE_NAME__' "$SERVICE_NAME"
  replace_placeholder "$INSTRUMENTATION_FILE" '__DEFAULT_SERVICE_VERSION__' "$SERVICE_VERSION"
  replace_placeholder "$INSTRUMENTATION_FILE" '__DEFAULT_PYROSCOPE_URL__' "$PYROSCOPE_URL"

  prepend_block_if_missing "$ENTRY_FILE" "startInstrumentation" "$EXPRESS_BOOTSTRAP"

  SUMMARY_LINES+=("   - Instrumentation file: $INSTRUMENTATION_FILE")
  SUMMARY_LINES+=("   - Entry file patched: $ENTRY_FILE")
elif [ "$FRAMEWORK" = "nestjs" ]; then
  INSTRUMENTATION_FILE="${SRC_DIR}/instrumentation.ts"
  backup_file "$INSTRUMENTATION_FILE"
  backup_file "$ENTRY_FILE"

  if [ ! -f "${TEMPLATE_DIR}/instrumentation.ts.tpl" ]; then
    echo "❌ Missing instrumentation template for ${FRAMEWORK}"
    exit 1
  fi

  cp "${TEMPLATE_DIR}/instrumentation.ts.tpl" "$INSTRUMENTATION_FILE"
  replace_placeholder "$INSTRUMENTATION_FILE" '__DEFAULT_OTLP_URL__' "$OTLP_URL"
  replace_placeholder "$INSTRUMENTATION_FILE" '__DEFAULT_SERVICE_NAME__' "$SERVICE_NAME"
  replace_placeholder "$INSTRUMENTATION_FILE" '__DEFAULT_SERVICE_VERSION__' "$SERVICE_VERSION"

  prepend_block_if_missing "$ENTRY_FILE" "startInstrumentation" "$NEST_BOOTSTRAP"

  SUMMARY_LINES+=("   - Instrumentation file: $INSTRUMENTATION_FILE")
  SUMMARY_LINES+=("   - Entry file patched: $ENTRY_FILE")
else
  INSTRUMENTATION_FILE="${PROJECT_ROOT}/instrumentation.ts"
  NODE_OTEL_FILE="${PROJECT_ROOT}/otel.ts"
  NEXT_CONFIG_FILE="${PROJECT_ROOT}/next.config.ts"

  backup_file "$INSTRUMENTATION_FILE"
  backup_file "$NODE_OTEL_FILE"
  backup_file "$NEXT_CONFIG_FILE"

  for template in instrumentation.ts.tpl otel.ts.tpl next.config.ts.tpl; do
    if [ ! -f "${TEMPLATE_DIR}/${template}" ]; then
      echo "❌ Missing template ${template} for ${FRAMEWORK_LABEL}"
      exit 1
    fi
  done

  cp "${TEMPLATE_DIR}/instrumentation.ts.tpl" "$INSTRUMENTATION_FILE"
  cp "${TEMPLATE_DIR}/otel.ts.tpl" "$NODE_OTEL_FILE"
  cp "${TEMPLATE_DIR}/next.config.ts.tpl" "$NEXT_CONFIG_FILE"

  replace_placeholder "$NODE_OTEL_FILE" '__DEFAULT_OTLP_URL__' "$OTLP_URL"
  replace_placeholder "$NODE_OTEL_FILE" '__DEFAULT_SERVICE_NAME__' "$SERVICE_NAME"
  replace_placeholder "$NODE_OTEL_FILE" '__DEFAULT_SERVICE_VERSION__' "$SERVICE_VERSION"

  SUMMARY_LINES+=("   - instrumentation.ts: $INSTRUMENTATION_FILE")
  SUMMARY_LINES+=("   - otel.ts: $NODE_OTEL_FILE")
  SUMMARY_LINES+=("   - next.config.ts: $NEXT_CONFIG_FILE")
fi

echo ""
echo "✅ LGTM instrumentation applied for ${FRAMEWORK_LABEL}"
for line in "${SUMMARY_LINES[@]}"; do
  echo "$line"
done
echo ""
echo "ℹ️  Runtime defaults"
echo "   OTEL_COLLECTOR_URL=${OTLP_URL}"
echo "   SERVICE_NAME=${SERVICE_NAME}"
echo "   SERVICE_VERSION=${SERVICE_VERSION}"
if [ "$FRAMEWORK" = "express" ]; then
  echo "   PYROSCOPE_ENDPOINT=${PYROSCOPE_URL}"
fi

echo "You can override these values via environment variables when running the app."
