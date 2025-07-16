# Helm Chart Build and Publish Scripts

This directory contains scripts to build and publish the StackStorm Helm chart.

## Scripts Overview

### 1. `build.sh` - Build the Helm Chart
Packages the chart dependencies and main chart with validation.

**Features:**
- Packages chart dependencies (MongoDB, RabbitMQ, Redis)
- Lints the chart for errors
- Creates the final chart package
- Colored output for better readability
- Error handling and validation

**Usage:**
```bash
./build.sh
```

### 2. `publish.sh` - Build and Publish Chart
Enhanced version of the original publish script with better error handling and features.

**Features:**
- Builds the chart (or skips if requested)
- Publishes to Artifactory
- Comprehensive error handling
- Command-line options for flexibility
- Dry-run capability
- Environment variable validation
- HTTP status code checking

**Usage:**
```bash
# Basic usage (build and publish)
./publish.sh

# Build only
./publish.sh --build-only

# Skip build, publish existing chart
./publish.sh --skip-build

# Dry run (show what would be done)
./publish.sh --dry-run

# Help
./publish.sh --help
```

### 3. `release.sh` - Version Management
Manages chart versioning and git tagging.

**Features:**
- Updates Chart.yaml version
- Creates git tags
- Pushes tags to remote
- Semantic version validation
- Backup and rollback on failure

**Usage:**
```bash
# Update version
./release.sh --version 1.3.11

# Update version and create/push git tag
./release.sh --version 1.4.0 --push-tag

# Help
./release.sh --help
```

## Environment Setup

### 1. Create Environment File
Copy and customize the environment template:

```bash
cp .env.template .env
```

Edit `.env` with your Artifactory credentials:
```bash
ARTIFACTORY_USERNAME=your_username
ARTIFACTORY_API_KEY=your_api_key
ARTIFACTORY_URL=https://artifactory-uw2.adobeitc.com/artifactory/helm-dx-stackstorm-release
```

### 2. Required Tools
- `helm` - Helm CLI tool
- `curl` - For uploading to Artifactory
- `git` - For version tagging (optional)

## Typical Workflow

### New Release Workflow
```bash
# 1. Update version
./release.sh --version 1.3.11 --push-tag

# 2. Build and publish
./publish.sh
```

### Development Workflow
```bash
# Build only for testing
./publish.sh --build-only

# Test with dry run
./publish.sh --dry-run

# Publish when ready
./publish.sh
```

### Quick Publish (existing version)
```bash
# Skip build if chart is already built
./publish.sh --skip-build
```

## Error Handling

All scripts include comprehensive error handling:
- Exit on any command failure (`set -euo pipefail`)
- Validation of required files and environment variables
- HTTP status code checking for uploads
- Backup and rollback capabilities
- Colored output for easy identification of issues

## Chart Dependencies

The scripts handle these chart dependencies:
- **MongoDB** (mongodb-10.0.1.tgz)
- **RabbitMQ** (rabbitmq-8.0.2.tgz)  
- **Redis** (redis-12.3.2.tgz)

Dependencies are automatically packaged from the `charts/` subdirectories.

## Troubleshooting

### Common Issues

1. **Missing .env file**
   ```bash
   cp .env.template .env
   # Edit with your credentials
   ```

2. **Chart lint failures**
   ```bash
   helm lint .
   # Fix any reported issues
   ```

3. **Upload failures**
   - Check Artifactory credentials
   - Verify network connectivity
   - Check if version already exists

4. **Permission denied**
   ```bash
   chmod +x *.sh
   ```

### Debug Mode
For debugging, you can run commands with verbose output:
```bash
bash -x ./publish.sh
```
