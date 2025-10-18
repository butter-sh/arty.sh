#!/usr/bin/env bash
# Test suite for arty YAML parsing functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTY_SH="${SCRIPT_DIR}/../arty.sh"

# Source test helpers
if ! declare -f assert_contains > /dev/null; then
    echo "Error: Test helpers not loaded. This test must be run via judge.sh"
    exit 1
fi


# Setup before each test
setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    # Create a test YAML file
    cat > "$TEST_DIR/test.yml" << 'EOF'
name: "test-project"
version: "1.2.3"
description: "A test project"
author: "Test Author"
license: "MIT"

references:
  - https://github.com/user/lib1.git
  - https://github.com/user/lib2.git

scripts:
  build: "npm run build"
  test: "npm test"
  deploy: "bash deploy.sh"
EOF
}

# Cleanup after each test
teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Test: get_yaml_field retrieves simple field
test_get_yaml_field_simple() {
    setup
    
    # Create a test script that uses get_yaml_field
    cat > "$TEST_DIR/test_field.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"
get_yaml_field "${2}" "name"
EOF
    
    output=$(bash "$TEST_DIR/test_field.sh" "$ARTY_SH" "$TEST_DIR/test.yml")
    
    assert_equals "test-project" "$output" "Should retrieve project name field"
    
    teardown
}

# Test: get_yaml_field retrieves version
test_get_yaml_field_version() {
    setup
    
    cat > "$TEST_DIR/test_version.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"
get_yaml_field "${2}" "version"
EOF
    
    output=$(bash "$TEST_DIR/test_version.sh" "$ARTY_SH" "$TEST_DIR/test.yml")
    
    assert_equals "1.2.3" "$output" "Should retrieve version field"
    
    teardown
}

# Test: get_yaml_field handles missing file
test_get_yaml_field_missing_file() {
    setup
    
    cat > "$TEST_DIR/test_missing.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"
get_yaml_field "nonexistent.yml" "name" && echo "found" || echo "not found"
EOF
    
    output=$(bash "$TEST_DIR/test_missing.sh" "$ARTY_SH")
    
    assert_contains "$output" "not found" "Should handle missing file gracefully"
    
    teardown
}

# Test: get_yaml_array retrieves references
test_get_yaml_array_references() {
    setup
    
    cat > "$TEST_DIR/test_array.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"
get_yaml_array "${2}" "references"
EOF
    
    output=$(bash "$TEST_DIR/test_array.sh" "$ARTY_SH" "$TEST_DIR/test.yml")
    
    assert_contains "$output" "https://github.com/user/lib1.git" "Should retrieve first reference"
    assert_contains "$output" "https://github.com/user/lib2.git" "Should retrieve second reference"
    
    teardown
}

# Test: get_yaml_script retrieves script command
test_get_yaml_script() {
    setup
    
    cat > "$TEST_DIR/test_script.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"
get_yaml_script "${2}" "build"
EOF
    
    output=$(bash "$TEST_DIR/test_script.sh" "$ARTY_SH" "$TEST_DIR/test.yml")
    
    assert_equals "npm run build" "$output" "Should retrieve script command"
    
    teardown
}

# Test: get_yaml_script returns null for missing script
test_get_yaml_script_missing() {
    setup
    
    cat > "$TEST_DIR/test_missing_script.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"
get_yaml_script "${2}" "nonexistent"
EOF
    
    output=$(bash "$TEST_DIR/test_missing_script.sh" "$ARTY_SH" "$TEST_DIR/test.yml")
    
    assert_equals "null" "$output" "Should return null for missing script"
    
    teardown
}

# Test: list_yaml_scripts lists all script names
test_list_yaml_scripts() {
    setup
    
    cat > "$TEST_DIR/test_list_scripts.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"
list_yaml_scripts "${2}"
EOF
    
    output=$(bash "$TEST_DIR/test_list_scripts.sh" "$ARTY_SH" "$TEST_DIR/test.yml")
    
    assert_contains "$output" "build" "Should list build script"
    assert_contains "$output" "test" "Should list test script"
    assert_contains "$output" "deploy" "Should list deploy script"
    
    teardown
}

# Test: YAML with empty arrays
test_yaml_empty_array() {
    setup
    
    cat > "$TEST_DIR/empty.yml" << 'EOF'
name: "empty-test"
references: []
EOF
    
    cat > "$TEST_DIR/test_empty.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"
result=$(get_yaml_array "${2}" "references")
if [[ -z "$result" ]]; then
    echo "empty"
else
    echo "not empty"
fi
EOF
    
    output=$(bash "$TEST_DIR/test_empty.sh" "$ARTY_SH" "$TEST_DIR/empty.yml")
    
    assert_equals "empty" "$output" "Should handle empty arrays"
    
    teardown
}

# Test: YAML with nested objects
test_yaml_nested_field() {
    setup
    
    cat > "$TEST_DIR/nested.yml" << 'EOF'
name: "nested-test"
config:
  setting1: "value1"
  setting2: "value2"
EOF
    
    cat > "$TEST_DIR/test_nested.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"
get_yaml_field "${2}" "config.setting1"
EOF
    
    output=$(bash "$TEST_DIR/test_nested.sh" "$ARTY_SH" "$TEST_DIR/nested.yml")
    
    assert_equals "value1" "$output" "Should retrieve nested field value"
    
    teardown
}

# Run all tests
run_tests() {
    log_section "YAML Parsing Tests"
    
    test_get_yaml_field_simple
    test_get_yaml_field_version
    test_get_yaml_field_missing_file
    test_get_yaml_array_references
    test_get_yaml_script
    test_get_yaml_script_missing
    test_list_yaml_scripts
    test_yaml_empty_array
    test_yaml_nested_field
    
    print_test_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
