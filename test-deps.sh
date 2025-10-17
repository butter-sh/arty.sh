#!/usr/bin/env bash

# Test script to verify deps command with yq

set -e

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "ERROR: yq is not installed"
    echo "Please install yq first:"
    echo "  macOS: brew install yq"
    echo "  Linux: see https://github.com/mikefarah/yq"
    exit 1
fi

echo "✓ yq is installed: $(yq --version)"
echo ""

# Create a temporary test directory
TEST_DIR=$(mktemp -d)
echo "Test directory: $TEST_DIR"
cd "$TEST_DIR"

# Create a sample arty.yml with actual Git references
cat > arty.yml << 'EOF'
name: "test-project"
version: "0.1.0"
description: "Test project for arty deps"
author: "Test"
license: "MIT"

# Real Git repositories for testing
references:
  - https://github.com/butter-sh/leaf.sh.git

main: "index.sh"

scripts:
  test: "echo 'Test running'"
  hello: "echo 'Hello from arty!'"
EOF

# Create a dummy main script
echo '#!/usr/bin/env bash' > index.sh
echo 'echo "Main script"' >> index.sh

echo "Created test arty.yml with Git references"
echo ""
cat arty.yml
echo ""

# Test yq can parse the file
echo "Testing yq parsing..."
echo "Name: $(yq eval '.name' arty.yml)"
echo "Version: $(yq eval '.version' arty.yml)"
echo "Main: $(yq eval '.main' arty.yml)"
echo "References:"
yq eval '.references[]' arty.yml
echo "Scripts:"
yq eval '.scripts | keys | .[]' arty.yml
echo ""

# Run deps command
echo "Running: arty deps"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bash "$SCRIPT_DIR/arty.sh" deps

echo ""
echo "Checking if dependencies were cloned..."
echo ""

# Check if .arty directory structure was created
if [[ -d ".arty" ]]; then
    echo "✓ .arty/ directory created"
else
    echo "✗ .arty/ directory NOT created"
    exit 1
fi

if [[ -d ".arty/bin" ]]; then
    echo "✓ .arty/bin/ directory created"
else
    echo "✗ .arty/bin/ directory NOT created"
    exit 1
fi

if [[ -d ".arty/libs" ]]; then
    echo "✓ .arty/libs/ directory created"
else
    echo "✗ .arty/libs/ directory NOT created"
    exit 1
fi

# Check if dependencies were cloned
if [[ -d ".arty/libs/leaf.sh" ]]; then
    echo "✓ leaf.sh dependency cloned"
    
    # Check if it's a Git repository
    if [[ -d ".arty/libs/leaf.sh/.git" ]]; then
        echo "✓ leaf.sh is a valid Git repository"
    else
        echo "✗ leaf.sh is NOT a valid Git repository"
        exit 1
    fi
    
    # List some files to verify content
    echo ""
    echo "Contents of .arty/libs/leaf.sh:"
    ls -la ".arty/libs/leaf.sh" | head -10
else
    echo "✗ leaf.sh dependency NOT cloned"
    exit 1
fi

# Check if main script was linked
if [[ -L ".arty/bin/index" ]]; then
    echo "✓ Main script linked to .arty/bin/index"
    
    # Check if it's executable
    if [[ -x "index.sh" ]]; then
        echo "✓ Main script is executable"
    else
        echo "✗ Main script is NOT executable"
        exit 1
    fi
else
    echo "✗ Main script NOT linked"
    exit 1
fi

echo ""
echo "Testing script execution..."
echo ""

# Test running a script from arty.yml
echo "Running: arty test"
bash "$SCRIPT_DIR/arty.sh" test

echo ""
echo "Running: arty hello"
bash "$SCRIPT_DIR/arty.sh" hello

echo ""
echo "Directory tree:"
tree -L 3 .arty 2>/dev/null || find .arty -type f -o -type d | head -20

echo ""
echo "✅ All tests passed! yq integration is working correctly."
echo ""
echo "Cleaning up test directory: $TEST_DIR"
cd ..
rm -rf "$TEST_DIR"
