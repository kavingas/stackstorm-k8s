#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_info "Building Helm chart dependencies and main chart..."

# Check if Chart.yaml exists
if [[ ! -f "Chart.yaml" ]]; then
    print_error "Chart.yaml not found in current directory"
    exit 1
fi

# Extract chart name and version from Chart.yaml
CHART_NAME=$(grep "^name:" Chart.yaml | awk '{print $2}')
CHART_VERSION=$(grep "^version:" Chart.yaml | awk '{print $2}')

print_info "Chart: $CHART_NAME"
print_info "Version: $CHART_VERSION"

# Create charts directory if it doesn't exist
mkdir -p charts

print_info "Building chart dependencies..."

# Change to charts directory
cd charts

# Package dependencies
if [[ -d "mongodb" ]]; then
    print_info "Packaging MongoDB dependency..."
    rm -f mongodb-*.tgz
    tar czf mongodb-10.0.1.tgz mongodb
    print_info "✓ MongoDB dependency packaged"
fi

if [[ -d "rabbitmq" ]]; then
    print_info "Packaging RabbitMQ dependency..."
    rm -f rabbitmq-*.tgz
    tar czf rabbitmq-8.0.2.tgz rabbitmq
    print_info "✓ RabbitMQ dependency packaged"
fi

if [[ -d "redis" ]]; then
    print_info "Packaging Redis dependency..."
    rm -f redis-*.tgz
    tar czf redis-12.3.2.tgz redis
    print_info "✓ Redis dependency packaged"
fi

# Return to main directory
cd ..

# Update dependencies if Chart.lock exists
if [[ -f "Chart.lock" ]]; then
    print_info "Updating Helm dependencies..."
    helm dependency update
fi

# Lint the chart
print_info "Linting Helm chart..."
if helm lint .; then
    print_info "✓ Chart linting passed"
else
    print_error "Chart linting failed"
    exit 1
fi

# Package the main chart
print_info "Packaging main Helm chart..."
if helm package .; then
    print_info "✓ Chart packaged successfully: ${CHART_NAME}-${CHART_VERSION}.tgz"
else
    print_error "Chart packaging failed"
    exit 1
fi

# Verify the package was created
if [[ -f "${CHART_NAME}-${CHART_VERSION}.tgz" ]]; then
    print_info "✓ Chart package verified: ${CHART_NAME}-${CHART_VERSION}.tgz"
else
    print_error "Chart package not found after build"
    exit 1
fi

print_info "Build completed successfully!"
