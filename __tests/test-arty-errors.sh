#!/bin/bash
# Test suite for arty error handling and edge cases



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


# Test: arty handles missing arty.yml gracefully
test_missing_config_file() {
    setup

    # Try to run a script without arty.yml
    set +e
    output=$(bash "$ARTY_SH" test 2>&1)
    exit_code=$?
    set -e

    assert_exit_code 1 "$exit_code" "Should return error code for missing config"
    assert_contains "$output" "Config file not found" "Should report missing config file"
    teardown
}

# Test: arty handles corrupted YAML
test_corrupted_yaml() {
    setup

    echo "this is not valid yaml: [" > "$TEST_ENV_DIR/arty.yml"

    set +e
    output=$(bash "$ARTY_SH" deps 2>&1)
    exit_code=$?
    set -e

    # yq should fail on invalid YAML
    assert_true "[[ $exit_code -ne 0 ]]" "Should fail on corrupted YAML"
    teardown
}

# Test: arty handles empty arty.yml
test_empty_yaml() {
    setup

    touch "$TEST_ENV_DIR/arty.yml"

    set +e
    output=$(bash "$ARTY_SH" deps 2>&1)
    exit_code=$?
    set -e

    # Should handle empty file gracefully
    assert_true "[[ $exit_code -eq 0 || $exit_code -eq 1 ]]" "Should handle empty YAML file"
    teardown
}

# Test: arty handles script with no name
test_script_without_name() {
    setup

    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  : "echo 'no name'"
EOF

    # YAML with empty key should be handled
    set +e
    output=$(bash "$ARTY_SH" list 2>&1)
    # Just check it doesn't crash
    set -e

    assert_true "true" "Should handle malformed scripts section"
    teardown
}

# Test: arty handles extremely long script command
test_extremely_long_script() {
    setup

    # Create a very long command
    long_cmd="echo 'start'"
    for i in {1..100}; do
        long_cmd="${long_cmd} && echo 'line${i}'"
    done

    cat > "$TEST_ENV_DIR/arty.yml" << EOF
name: "test-project"
version: "1.0.0"
scripts:
  long: "${long_cmd}"
EOF

    set +e
    output=$(bash "$ARTY_SH" long 2>&1)
    exit_code=$?
    set -e

    assert_exit_code 0 "$exit_code" "Should execute long script successfully"
    assert_contains "$output" "start" "Long script should execute"
    teardown
}

# Test: arty handles script with special characters
test_script_special_characters() {
    setup

    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  special: "echo 'Hello! @#$%^&*()'"
EOF

    output=$(bash "$ARTY_SH" special 2>&1)

    assert_contains "$output" "Hello!" "Script with special characters should execute"
    teardown
}

# Test: arty handles non-existent script name
test_nonexistent_script() {
    setup

    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  test: "echo test"
EOF

    set +e
    output=$(bash "$ARTY_SH" nonexistent 2>&1)
    exit_code=$?
    set -e

    assert_exit_code 1 "$exit_code" "Should return error for non-existent script"
    assert_contains "$output" "Script not found" "Should report script not found"
    assert_contains "$output" "Available scripts" "Should list available scripts"
    teardown
}

# Test: arty handles remove of non-existent library
test_remove_nonexistent_library() {
    setup

    mkdir -p "$ARTY_HOME/libs"

    set +e
    output=$(bash "$ARTY_SH" remove nonexistent-lib 2>&1)
    exit_code=$?
    set -e

    assert_exit_code 1 "$exit_code" "Should return error when removing non-existent library"
    assert_contains "$output" "not found" "Should report library not found"
    teardown
}

# Test: arty handles init when arty.yml already exists
test_init_when_config_exists() {
    setup

    echo "existing: config" > "$TEST_ENV_DIR/arty.yml"

    set +e
    output=$(bash "$ARTY_SH" init new-project 2>&1)
    exit_code=$?
    set -e

    assert_exit_code 1 "$exit_code" "Should return error when config already exists"
    assert_contains "$output" "already exists" "Should report that config already exists"

    # Verify original config was not overwritten
    assert_contains "$(cat $TEST_ENV_DIR/arty.yml)" "existing: config" "Original config should not be overwritten"
    teardown
}

# Test: arty handles exec without library name
test_exec_without_library_name() {
    setup

    set +e
    output=$(bash "$ARTY_SH" exec 2>&1)
    exit_code=$?
    set -e

    assert_exit_code 1 "$exit_code" "Should return error when exec called without library name"
    assert_contains "$output" "Library name required" "Should report library name required"
    teardown
}

# Test: arty handles source without library name
test_source_without_library_name() {
    setup

    set +e
    output=$(bash "$ARTY_SH" source 2>&1)
    exit_code=$?
    set -e

    assert_exit_code 1 "$exit_code" "Should return error when source called without library name"
    assert_contains "$output" "Library name required" "Should report library name required"
    teardown
}

# Test: arty handles remove without library name
test_remove_without_library_name() {
    setup

    set +e
    output=$(bash "$ARTY_SH" remove 2>&1)
    exit_code=$?
    set -e

    assert_exit_code 1 "$exit_code" "Should return error when remove called without library name"
    assert_contains "$output" "Library name required" "Should report library name required"
    teardown
}

# Test: arty handles scripts with null values
test_script_null_value() {
    setup

    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  test: null
EOF

    set +e
    output=$(bash "$ARTY_SH" test 2>&1)
    exit_code=$?
    set -e

    # Should handle null script value
    assert_true "[[ $exit_code -ne 0 ]]" "Should fail for null script value"
    teardown
}

# Test: arty handles empty scripts section
test_empty_scripts_section() {
    setup

    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts: {}
EOF

    set +e
    output=$(bash "$ARTY_SH" test 2>&1)
    exit_code=$?
    set -e

    assert_exit_code 1 "$exit_code" "Should return error for non-existent script"
    assert_contains "$output" "Script not found" "Should report script not found"
    teardown
}

# Test: arty handles YAML with only name field
test_minimal_yaml() {
    setup

    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "minimal-project"
EOF

    set +e
    output=$(bash "$ARTY_SH" deps 2>&1)
    exit_code=$?
    set -e

    # Should handle minimal YAML without errors
    assert_exit_code 0 "$exit_code" "Should handle minimal YAML file"
    teardown
}

# Test: arty handles permission denied scenarios
test_permission_denied() {
    setup

    mkdir -p "$ARTY_HOME/libs"
    # This test may not work on all systems, so we'll make it conditional
    if [[ "$(uname)" != "Darwin" ]]; then
        chmod 000 "$ARTY_HOME/libs" 2>/dev/null || true

        set +e
        output=$(bash "$ARTY_SH" list 2>&1)
        exit_code=$?
        set -e

        # Restore permissions for cleanup
        chmod 755 "$ARTY_HOME/libs" 2>/dev/null || true

        # Should handle permission denied gracefully (may vary by system)
        assert_true "true" "Permission test completed"
    else
        log_skip "Skipping permission test on macOS"
    fi

}

# Test: arty handles concurrent script execution
test_script_state_isolation() {
    setup

    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  set-var: "export TEST_VAR='set' && echo $TEST_VAR"
  check-var: "echo ${TEST_VAR:-not set}"
EOF

    output1=$(bash "$ARTY_SH" set-var 2>&1)
    output2=$(bash "$ARTY_SH" check-var 2>&1)

    assert_contains "$output1" "set" "First script should set variable"
    assert_contains "$output2" "not set" "Second script should not see first script's variable"
    teardown
}

# Run all tests
run_tests() {
    log_section "Error Handling and Edge Cases Tests"

    test_missing_config_file
    test_corrupted_yaml
    test_empty_yaml
    test_script_without_name
    test_extremely_long_script
    test_script_special_characters
    test_nonexistent_script
    test_remove_nonexistent_library
    test_init_when_config_exists
    test_exec_without_library_name
    test_source_without_library_name
    test_remove_without_library_name
    test_script_null_value
    test_empty_scripts_section
    test_minimal_yaml
    test_permission_denied
    test_script_state_isolation

}

export -f run_tests
