#!/usr/bin/env bash

# Quick test to verify yq functions work

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Source the arty.sh to get the helper functions
source "$SCRIPT_DIR/arty.sh"

# Create a test YAML file
TEST_FILE=$(mktemp)
cat > "$TEST_FILE" << 'EOF'
name: "test-lib"
version: "1.2.3"
description: "A test library"
main: "lib.sh"

references:
  - https://github.com/user/dep1.git
  - https://github.com/user/dep2.git

scripts:
  test: "bash test.sh"
  build: "bash build.sh"
  deploy: "echo deploying"
EOF

echo "Testing yq helper functions..."
echo ""

echo "Test YAML file:"
cat "$TEST_FILE"
echo ""

echo "Testing get_yaml_field..."
name=$(get_yaml_field "$TEST_FILE" "name")
echo "  name: $name"
[[ "$name" == "test-lib" ]] && echo "  ✓ PASS" || echo "  ✗ FAIL"

version=$(get_yaml_field "$TEST_FILE" "version")
echo "  version: $version"
[[ "$version" == "1.2.3" ]] && echo "  ✓ PASS" || echo "  ✗ FAIL"

main=$(get_yaml_field "$TEST_FILE" "main")
echo "  main: $main"
[[ "$main" == "lib.sh" ]] && echo "  ✓ PASS" || echo "  ✗ FAIL"

echo ""
echo "Testing get_yaml_array..."
echo "  references:"
count=0
while IFS= read -r ref; do
    echo "    - $ref"
    ((count++))
done < <(get_yaml_array "$TEST_FILE" "references")
[[ $count -eq 2 ]] && echo "  ✓ PASS (found 2 references)" || echo "  ✗ FAIL (expected 2, got $count)"

echo ""
echo "Testing get_yaml_script..."
test_cmd=$(get_yaml_script "$TEST_FILE" "test")
echo "  scripts.test: $test_cmd"
[[ "$test_cmd" == "bash test.sh" ]] && echo "  ✓ PASS" || echo "  ✗ FAIL"

build_cmd=$(get_yaml_script "$TEST_FILE" "build")
echo "  scripts.build: $build_cmd"
[[ "$build_cmd" == "bash build.sh" ]] && echo "  ✓ PASS" || echo "  ✗ FAIL"

deploy_cmd=$(get_yaml_script "$TEST_FILE" "deploy")
echo "  scripts.deploy: $deploy_cmd"
[[ "$deploy_cmd" == "echo deploying" ]] && echo "  ✓ PASS" || echo "  ✗ FAIL"

echo ""
echo "Testing list_yaml_scripts..."
echo "  Available scripts:"
script_count=0
while IFS= read -r script_name; do
    echo "    - $script_name"
    ((script_count++))
done < <(list_yaml_scripts "$TEST_FILE")
[[ $script_count -eq 3 ]] && echo "  ✓ PASS (found 3 scripts)" || echo "  ✗ FAIL (expected 3, got $script_count)"

echo ""
echo "✅ All yq function tests completed!"

# Cleanup
rm "$TEST_FILE"
