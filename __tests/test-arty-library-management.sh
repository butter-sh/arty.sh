#!/bin/bash
# Test suite for arty library management (list, remove, source)

# Setup before each test
setup() {
  TEST_ENV_DIR=$(create_test_env)
  export ARTY_HOME="$TEST_ENV_DIR/.arty"
  export ARTY_CONFIG_FILE="$TEST_ENV_DIR/arty.yml"
  cd "$TEST_ENV_DIR"
}

teardown() {
  cleanup_test_env
  cd /
}

# Test: list shows no libraries when empty
test_list_empty() {
  setup

  mkdir -p "$ARTY_HOME/libs"
  output=$(bash "$ARTY_SH" list 2>&1)

  assert_contains "$output" "No libraries installed" "Should show no libraries message"
  teardown
}

# Test: list shows installed libraries
test_list_installed_libraries() {
  setup

  mkdir -p "$ARTY_HOME/libs/lib1"
  mkdir -p "$ARTY_HOME/libs/lib2"
  mkdir -p "$ARTY_HOME/libs/lib3"

  output=$(bash "$ARTY_SH" list 2>&1)

  assert_contains "$output" "lib1" "Should list lib1"
  assert_contains "$output" "lib2" "Should list lib2"
  assert_contains "$output" "lib3" "Should list lib3"
  assert_contains "$output" "Installed libraries" "Should have header"
  teardown
}

# Test: list shows version from arty.yml
test_list_shows_version() {
  setup

  mkdir -p "$ARTY_HOME/libs/test-lib"
  cat >"$ARTY_HOME/libs/test-lib/arty.yml" <<'EOF'
name: "test-lib"
version: "2.5.1"
EOF

  output=$(bash "$ARTY_SH" list 2>&1)

  assert_contains "$output" "test-lib" "Should list library name"
  assert_contains "$output" "2.5.1" "Should show version number"
  teardown
}

# Test: list handles library without arty.yml
test_list_without_arty_yml() {
  setup

  mkdir -p "$ARTY_HOME/libs/no-config-lib"

  output=$(bash "$ARTY_SH" list 2>&1)

  assert_contains "$output" "no-config-lib" "Should list library even without config"
  assert_contains "$output" "unknown version" "Should show unknown version"
  teardown
}

# Test: list handles library with malformed arty.yml
test_list_malformed_config() {
  setup

  mkdir -p "$ARTY_HOME/libs/bad-lib"
  echo "not valid yaml [" >"$ARTY_HOME/libs/bad-lib/arty.yml"

  output=$(bash "$ARTY_SH" list 2>&1)

  assert_contains "$output" "bad-lib" "Should still list library with bad config"
  teardown
}

# Test: ls alias works same as list
test_ls_alias() {
  setup

  mkdir -p "$ARTY_HOME/libs/test-lib"

  output1=$(bash "$ARTY_SH" list 2>&1)
  output2=$(bash "$ARTY_SH" ls 2>&1)

  # Both should produce similar output
  assert_contains "$output1" "test-lib" "list should show library"
  assert_contains "$output2" "test-lib" "ls should show library"
  teardown
}

# Test: remove deletes library directory
test_remove_deletes_library() {
  setup

  mkdir -p "$ARTY_HOME/libs/to-remove"
  echo "content" >"$ARTY_HOME/libs/to-remove/file.txt"

  assert_directory_exists "$ARTY_HOME/libs/to-remove" "Library should exist before removal"

  output=$(bash "$ARTY_SH" remove to-remove 2>&1)

  assert_contains "$output" "removed" "Should confirm removal"
  assert_false "[[ -d '$ARTY_HOME/libs/to-remove' ]]" "Library directory should be deleted"
  teardown
}

# Test: remove fails for non-existent library
test_remove_nonexistent() {
  setup

  mkdir -p "$ARTY_HOME/libs"

  set +e
  output=$(bash "$ARTY_SH" remove nonexistent 2>&1)
  exit_code=$?
  set -e

  assert_exit_code 1 "$exit_code" "Should return error code"
  assert_contains "$output" "not found" "Should report library not found"
  teardown
}

# Test: rm alias works same as remove
test_rm_alias() {
  setup

  mkdir -p "$ARTY_HOME/libs/test-lib"

  output=$(bash "$ARTY_SH" rm test-lib 2>&1)

  assert_contains "$output" "removed" "rm alias should work"
  assert_false "[[ -d '$ARTY_HOME/libs/test-lib' ]]" "Library should be deleted"
  teardown
}

# Test: remove handles library with nested directories
test_remove_nested_directories() {
  setup

  mkdir -p "$ARTY_HOME/libs/complex-lib/src/utils"
  mkdir -p "$ARTY_HOME/libs/complex-lib/tests"
  echo "content" >"$ARTY_HOME/libs/complex-lib/src/utils/helper.sh"
  echo "test" >"$ARTY_HOME/libs/complex-lib/tests/test.sh"

  bash "$ARTY_SH" remove complex-lib 2>&1

  assert_false "[[ -d '$ARTY_HOME/libs/complex-lib' ]]" "Complex library tree should be deleted"
  teardown
}

# Test: source loads library file
test_source_loads_library() {
  setup

  mkdir -p "$ARTY_HOME/libs/source-test"
  cat >"$ARTY_HOME/libs/source-test/index.sh" <<'EOF'
test_function() {
    echo "Function from library"
}
export TEST_VAR="library variable"
EOF

  # Create a test script that sources the library
  cat >"$TEST_ENV_DIR/test_source.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
source "${2}"
source_lib "source-test"
test_function
echo "$TEST_VAR"
EOF

  output=$(bash "$TEST_ENV_DIR/test_source.sh" "$ARTY_HOME" "$ARTY_SH")

  assert_contains "$output" "Function from library" "Should execute function from sourced library"
  assert_contains "$output" "library variable" "Should access variable from sourced library"
  teardown
}

# Test: source with custom file
test_source_custom_file() {
  setup

  mkdir -p "$ARTY_HOME/libs/custom-test"
  cat >"$ARTY_HOME/libs/custom-test/custom.sh" <<'EOF'
echo "Custom file loaded"
EOF

  cat >"$TEST_ENV_DIR/test_custom.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
source "${2}"
source_lib "custom-test" "custom.sh"
EOF

  output=$(bash "$TEST_ENV_DIR/test_custom.sh" "$ARTY_HOME" "$ARTY_SH")

  assert_contains "$output" "Custom file loaded" "Should load custom file"
  teardown
}

# Test: source fails for non-existent library
test_source_nonexistent_library() {
  setup

  mkdir -p "$ARTY_HOME/libs"

  cat >"$TEST_ENV_DIR/test_source_fail.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
source "${2}"
set +e
source_lib "nonexistent" 2>&1
exit_code=$?
set -e
exit $exit_code
EOF

  set +e
  output=$(bash "$TEST_ENV_DIR/test_source_fail.sh" "$ARTY_HOME" "$ARTY_SH" 2>&1)
  exit_code=$?
  set -e

  assert_exit_code 1 "$exit_code" "Should return error code"
  assert_contains "$output" "not found" "Should report file not found"
  teardown
}

# Test: source fails for non-existent file in library
test_source_nonexistent_file() {
  setup

  mkdir -p "$ARTY_HOME/libs/test-lib"

  cat >"$TEST_ENV_DIR/test_missing_file.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
source "${2}"
set +e
source_lib "test-lib" "missing.sh" 2>&1
exit_code=$?
set -e
exit $exit_code
EOF

  set +e
  output=$(bash "$TEST_ENV_DIR/test_missing_file.sh" "$ARTY_HOME" "$ARTY_SH" 2>&1)
  exit_code=$?
  set -e

  assert_exit_code 1 "$exit_code" "Should return error code"
  teardown
}

# Test: list handles many libraries
test_list_many_libraries() {
  setup

  # Create 50 libraries
  for i in {1..50}; do
    mkdir -p "$ARTY_HOME/libs/lib$i"
  done

  output=$(bash "$ARTY_SH" list 2>&1)

  assert_contains "$output" "lib1" "Should list first library"
  assert_contains "$output" "lib25" "Should list middle library"
  assert_contains "$output" "lib50" "Should list last library"
  teardown
}

# Test: list formatting is aligned
test_list_formatting() {
  setup

  mkdir -p "$ARTY_HOME/libs/short"
  mkdir -p "$ARTY_HOME/libs/very-long-library-name"

  cat >"$ARTY_HOME/libs/short/arty.yml" <<'EOF'
version: "1.0.0"
EOF

  cat >"$ARTY_HOME/libs/very-long-library-name/arty.yml" <<'EOF'
version: "2.3.4"
EOF

  output=$(bash "$ARTY_SH" list 2>&1)

  # Check that both libraries are listed
  assert_contains "$output" "short" "Should list short name"
  assert_contains "$output" "very-long-library-name" "Should list long name"
  assert_contains "$output" "1.0.0" "Should show first version"
  assert_contains "$output" "2.3.4" "Should show second version"
  teardown
}

# Run all tests
run_tests() {
  log_section "Library Management Tests"

  test_list_empty
  test_list_installed_libraries
  test_list_shows_version
  test_list_without_arty_yml
  test_list_malformed_config
  test_ls_alias
  test_remove_deletes_library
  test_remove_nonexistent
  test_rm_alias
  test_remove_nested_directories
  test_source_loads_library
  test_source_custom_file
  test_source_nonexistent_library
  test_source_nonexistent_file
  test_list_many_libraries
  test_list_formatting

}

export -f run_tests
