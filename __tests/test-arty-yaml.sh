#!/bin/bash
# Test suite for arty YAML parsing functionality

# Setup before each test
setup() {
  TEST_ENV_DIR=$(create_test_env)
  export ARTY_HOME="$TEST_ENV_DIR/.arty"
  export ARTY_CONFIG_FILE="$TEST_ENV_DIR/arty.yml"
  cd "$TEST_ENV_DIR"

  # Create a test YAML file
  cat >"$TEST_ENV_DIR/test.yml" <<'EOF'
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

teardown() {
  cleanup_test_env
}

# Test: get_yaml_field retrieves simple field
test_get_yaml_field_simple() {
  setup

  # Create a test script that uses get_yaml_field
  cat >"$TEST_ENV_DIR/test_field.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
get_yaml_field "${2}" "name"
EOF

  output=$(bash "$TEST_ENV_DIR/test_field.sh" "$ARTY_SH" "$TEST_ENV_DIR/test.yml")

  assert_equals "test-project" "$output" "Should retrieve project name field"
  teardown
}

# Test: get_yaml_field retrieves version
test_get_yaml_field_version() {
  setup

  cat >"$TEST_ENV_DIR/test_version.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
get_yaml_field "${2}" "version"
EOF

  output=$(bash "$TEST_ENV_DIR/test_version.sh" "$ARTY_SH" "$TEST_ENV_DIR/test.yml")

  assert_equals "1.2.3" "$output" "Should retrieve version field"
    teardown
}

# Test: get_yaml_field handles missing file
test_get_yaml_field_missing_file() {
  setup

  cat >"$TEST_ENV_DIR/test_missing.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
get_yaml_field "nonexistent.yml" "name" && echo "found" || echo "not found"
EOF

  output=$(bash "$TEST_ENV_DIR/test_missing.sh" "$ARTY_SH")

  assert_contains "$output" "not found" "Should handle missing file gracefully"
  teardown
}

# Test: get_yaml_array retrieves references
test_get_yaml_array_references() {
  setup

  cat >"$TEST_ENV_DIR/test_array.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
get_yaml_array "${2}" "references"
EOF

  output=$(bash "$TEST_ENV_DIR/test_array.sh" "$ARTY_SH" "$TEST_ENV_DIR/test.yml")

  assert_contains "$output" "https://github.com/user/lib1.git" "Should retrieve first reference"
  assert_contains "$output" "https://github.com/user/lib2.git" "Should retrieve second reference"
  teardown
}

# Test: get_yaml_script retrieves script command
test_get_yaml_script() {
  setup

  cat >"$TEST_ENV_DIR/test_script.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
get_yaml_script "${2}" "build"
EOF

  output=$(bash "$TEST_ENV_DIR/test_script.sh" "$ARTY_SH" "$TEST_ENV_DIR/test.yml")

  assert_equals "npm run build" "$output" "Should retrieve script command"
  teardown
}

# Test: get_yaml_script returns null for missing script
test_get_yaml_script_missing() {
  setup

  cat >"$TEST_ENV_DIR/test_missing_script.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
get_yaml_script "${2}" "nonexistent"
EOF

  output=$(bash "$TEST_ENV_DIR/test_missing_script.sh" "$ARTY_SH" "$TEST_ENV_DIR/test.yml")

  assert_equals "null" "$output" "Should return null for missing script"
  teardown
}

# Test: list_yaml_scripts lists all script names
test_list_yaml_scripts() {
  setup

  cat >"$TEST_ENV_DIR/test_list_scripts.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
list_yaml_scripts "${2}"
EOF

  output=$(bash "$TEST_ENV_DIR/test_list_scripts.sh" "$ARTY_SH" "$TEST_ENV_DIR/test.yml")

  assert_contains "$output" "build" "Should list build script"
  assert_contains "$output" "test" "Should list test script"
  assert_contains "$output" "deploy" "Should list deploy script"
  teardown
}

# Test: YAML with empty arrays
test_yaml_empty_array() {
  setup

  cat >"$TEST_ENV_DIR/empty.yml" <<'EOF'
name: "empty-test"
references: []
EOF

  cat >"$TEST_ENV_DIR/test_empty.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
result=$(get_yaml_array "${2}" "references")
if [[ -z "$result" ]]; then
    echo "empty"
else
    echo "not empty"
fi
EOF

  output=$(bash "$TEST_ENV_DIR/test_empty.sh" "$ARTY_SH" "$TEST_ENV_DIR/empty.yml")

  assert_equals "empty" "$output" "Should handle empty arrays"
  teardown
}

# Test: YAML with nested objects
test_yaml_nested_field() {
  setup

  cat >"$TEST_ENV_DIR/nested.yml" <<'EOF'
name: "nested-test"
config:
  setting1: "value1"
  setting2: "value2"
EOF

  cat >"$TEST_ENV_DIR/test_nested.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
get_yaml_field "${2}" "config.setting1"
EOF

  output=$(bash "$TEST_ENV_DIR/test_nested.sh" "$ARTY_SH" "$TEST_ENV_DIR/nested.yml")

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

}

export -f run_tests
