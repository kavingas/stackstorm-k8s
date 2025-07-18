#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse command line arguments
NEW_VERSION=""
SKIP_VERSION_UPDATE=false
SKIP_GIT_TAG=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            NEW_VERSION="$2"
            shift 2
            ;;
        --skip-version-update)
            SKIP_VERSION_UPDATE=true
            shift
            ;;
        --skip-git-tag)
            SKIP_GIT_TAG=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Build and publish Helm chart with automatic version management"
            echo ""
            echo "Options:"
            echo "  --version VERSION       Set new version (updates Chart.yaml and creates git tag)"
            echo "  --skip-version-update   Don't update Chart.yaml version"
            echo "  --skip-git-tag          Don't create/push git tag"
            echo "  --dry-run               Show what would be done without actually doing it"
            echo "  -h, --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --version 1.3.17     # Update to version 1.3.17 and publish"
            echo "  $0                       # Use current Chart.yaml version"
            echo "  $0 --skip-git-tag       # Publish without git operations"
            exit 0
            ;;
        *)
            print_error "Unknown option $1"
            exit 1
            ;;
    esac
done

print_step "Starting Helm chart build and publish process..."

# Check if Chart.yaml exists
if [[ ! -f "Chart.yaml" ]]; then
    print_error "Chart.yaml not found in current directory"
    exit 1
fi

# Get current version from Chart.yaml
CURRENT_VERSION=$(grep "^version:" Chart.yaml | awk '{print $2}')
print_info "Current Chart.yaml version: $CURRENT_VERSION"

# Determine version to use
if [[ -n "$NEW_VERSION" ]]; then
    VERSION="$NEW_VERSION"
    print_info "Target version: $VERSION"
    
    # Validate version format (basic semver check)
    if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
        print_error "Invalid version format. Use semantic versioning (e.g., 1.3.17, 2.0.0-alpha.1)"
        exit 1
    fi
    
    # Update Chart.yaml version if not skipped
    if [[ "$SKIP_VERSION_UPDATE" == "false" ]]; then
        print_step "Updating Chart.yaml version from $CURRENT_VERSION to $VERSION..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            print_info "[DRY RUN] Would update Chart.yaml version to $VERSION"
        else
            # Create backup
            cp Chart.yaml Chart.yaml.bak
            
            # Update version in Chart.yaml
            sed -i.tmp "s/^version: .*/version: $VERSION/" Chart.yaml
            rm -f Chart.yaml.tmp
            
            # Verify the change
            NEW_VERSION_CHECK=$(grep "^version:" Chart.yaml | awk '{print $2}')
            if [[ "$NEW_VERSION_CHECK" == "$VERSION" ]]; then
                print_info "✓ Chart.yaml updated successfully"
                rm -f Chart.yaml.bak
            else
                print_error "Failed to update Chart.yaml"
                mv Chart.yaml.bak Chart.yaml
                exit 1
            fi
        fi
    fi
else
    VERSION="$CURRENT_VERSION"
    print_info "Using current version: $VERSION"
fi

# Load environment variables from .env file
if [[ -f ".env" ]]; then
    print_info "Loading environment variables from .env file..."
    set -o allexport
    source .env
    set +o allexport
else
    print_warn ".env file not found. Please create one based on .env.template"
    if [[ ! -f ".env.template" ]]; then
        print_error ".env.template not found either. Please set ARTIFACTORY_USERNAME and ARTIFACTORY_API_KEY environment variables."
    fi
    exit 1
fi

# Validate required environment variables
if [[ -z "${ARTIFACTORY_USERNAME:-}" ]]; then
    print_error "ARTIFACTORY_USERNAME not set"
    exit 1
fi

if [[ -z "${ARTIFACTORY_API_KEY:-}" ]]; then
    print_error "ARTIFACTORY_API_KEY not set"
    exit 1
fi

# Set default values for optional variables
ARTIFACTORY_URL="${ARTIFACTORY_URL:-https://artifactory-uw2.adobeitc.com/artifactory/helm-dx-stackstorm-release}"

print_step "Building Helm chart dependencies..."

if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would build chart dependencies and package"
else
    # Create charts directory if it doesn't exist
    mkdir -p charts
    
    # Change to charts directory and package dependencies
    cd charts
    
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
    
    cd ..
    
    # Package the main chart
    print_info "Packaging main Helm chart..."
    if helm package .; then
        print_info "✓ Chart packaged successfully: stackstorm-ha-${VERSION}.tgz"
    else
        print_error "Chart packaging failed"
        exit 1
    fi
fi

# Verify chart package exists (unless dry run)
CHART_PACKAGE="stackstorm-ha-${VERSION}.tgz"
if [[ "$DRY_RUN" == "false" && ! -f "$CHART_PACKAGE" ]]; then
    print_error "Chart package not found: $CHART_PACKAGE"
    exit 1
fi

# Git operations
if [[ "$SKIP_GIT_TAG" == "false" ]]; then
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_warn "Not in a git repository, skipping git tag creation"
    else
        TAG_NAME="v$VERSION"
        
        # Check if tag already exists
        if git tag -l | grep -q "^$TAG_NAME$"; then
            print_warn "Tag $TAG_NAME already exists, skipping tag creation"
        else
            print_step "Creating and pushing git tag: $TAG_NAME"
            
            if [[ "$DRY_RUN" == "true" ]]; then
                print_info "[DRY RUN] Would create and push git tag: $TAG_NAME"
            else
                # Add Chart.yaml to git if it was modified
                if [[ -n "$NEW_VERSION" && "$SKIP_VERSION_UPDATE" == "false" ]]; then
                    git add Chart.yaml
                    if git commit -m "Bump version to $VERSION"; then
                        print_info "✓ Committed version change"
                    else
                        print_warn "No changes to commit (version may already be current)"
                    fi
                fi
                
                # Create tag
                if git tag -a "$TAG_NAME" -m "Release version $VERSION"; then
                    print_info "✓ Created tag: $TAG_NAME"
                    
                    # Push tag to remote
                    if git push origin "$TAG_NAME"; then
                        print_info "✓ Pushed tag: $TAG_NAME"
                    else
                        print_error "Failed to push tag: $TAG_NAME"
                        exit 1
                    fi
                else
                    print_error "Failed to create tag: $TAG_NAME"
                    exit 1
                fi
            fi
        fi
    fi
fi

# Publish the chart
print_step "Publishing Helm chart to Artifactory..."

UPLOAD_URL="${ARTIFACTORY_URL}/stackstorm-ha-${VERSION}.tgz"

print_info "Uploading to: $UPLOAD_URL"
print_info "Chart package: $CHART_PACKAGE"

if [[ "$DRY_RUN" == "false" ]]; then
    print_info "Size: $(ls -lh "$CHART_PACKAGE" | awk '{print $5}')"
fi

if [[ "$DRY_RUN" == "true" ]]; then
    print_info "[DRY RUN] Would upload $CHART_PACKAGE to $UPLOAD_URL"
    print_info "[DRY RUN] Command: curl -u\"$ARTIFACTORY_USERNAME:***\" -T \"$CHART_PACKAGE\" \"$UPLOAD_URL\""
else
    print_info "Uploading chart package..."
    
    # Use curl to upload with better error handling
    HTTP_CODE=$(curl -u"$ARTIFACTORY_USERNAME:$ARTIFACTORY_API_KEY" \
        -T "$CHART_PACKAGE" \
        -w "%{http_code}" \
        -s \
        -o /tmp/curl_response.txt \
        "$UPLOAD_URL")
    
    if [[ "$HTTP_CODE" == "201" || "$HTTP_CODE" == "200" ]]; then
        print_info "✓ Chart uploaded successfully!"
        print_info "✓ HTTP Status: $HTTP_CODE"
        print_info "✓ Chart available at: $UPLOAD_URL"
    else
        print_error "Upload failed with HTTP status: $HTTP_CODE"
        print_error "Response:"
        cat /tmp/curl_response.txt
        rm -f /tmp/curl_response.txt
        exit 1
    fi
    
    # Clean up temp file
    rm -f /tmp/curl_response.txt
fi

print_step "Process completed successfully!"
print_info "Chart: stackstorm-ha"
print_info "Version: $VERSION"
print_info "Package: $CHART_PACKAGE"

if [[ "$DRY_RUN" == "false" ]]; then
    print_info "Published to: $UPLOAD_URL"
    if [[ "$SKIP_GIT_TAG" == "false" ]] && git rev-parse --git-dir > /dev/null 2>&1; then
        print_info "Git tag: v$VERSION"
    fi
fi
