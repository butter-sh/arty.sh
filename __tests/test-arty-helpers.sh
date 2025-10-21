#!/bin/bash
# Test suite for arty helper functions and utilities

# Setup before each test
setup() {
  TEST_ENV_DIR=$(create_test_env)
  export ARTY_HOME="$TEST_ENV_DIR/.arty"
  export ARTY_CONFIG_FILE="$TEST_ENV_DIR/arty.yml"
  cd "$TEST_ENV_DIR"
}

teardown() {
  cleanup_test_env
}

# Test: check_yq detects missing yq
test_check_yq_detects_missing() {
    setup

    # Create a test script that modifies PATH to hide yq
    cat > "$TEST_ENV_DIR/test_no_yq.sh" << 'EOF'
#!/usr/bin/env bash
PATH="/nonexistent"
source "${1}"
check_yq 2>&1 || true
EOF

    output=$(bash "$TEST_ENV_DIR/test_no_yq.sh" "$ARTY_SH")

    assert_contains "$output" "yq is not installed"

    teardown
}

# Test: is_installed checks directory existence
test_is_installed_check() {
    setup

    export ARTY_HOME="$TEST_ENV_DIR/.arty"
    mkdir -p "$ARTY_HOME/libs/test-lib"

    cat > "$TEST_ENV_DIR/test_installed.sh" << 'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
source "${2}"
if is_installed "test-lib"; then
    echo "installed"
else
    echo "not installed"
fi
EOF

    output=$(bash "$TEST_ENV_DIR/test_installed.sh" "$ARTY_HOME" "$ARTY_SH")

    assert_equals "$output" "installed"
    teardown
}

# Test: is_installed returns false for non-existent library
test_is_installed_not_found() {
    setup

    export ARTY_HOME="$TEST_ENV_DIR/.arty"
    mkdir -p "$ARTY_HOME/libs"

    cat > "$TEST_ENV_DIR/test_not_installed.sh" << 'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
source "${2}"
if is_installed "nonexistent"; then
    echo "installed"
else
    echo "not installed"
fi
EOF

    output=$(bash "$TEST_ENV_DIR/test_not_installed.sh" "$ARTY_HOME" "$ARTY_SH")

    assert_equals "$output" "not installed"
    teardown
}

# Test: mark_installing and is_installing
test_circular_dependency_detection() {
    setup

    cat > "$TEST_ENV_DIR/test_circular.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"

# Test marking as installing
mark_installing "lib1"
if is_installing "lib1"; then
    echo "lib1 marked"
fi

# Test unmarking
unmark_installing "lib1"
if is_installing "lib1"; then
    echo "still marked"
else
    echo "unmarked"
fi
EOF

    output=$(bash "$TEST_ENV_DIR/test_circular.sh" "$ARTY_SH")

    assert_contains "$output" "lib1 marked"
    assert_contains "$output" "unmarked"
    teardown
}

# Test: get_lib_name extracts library name
test_get_lib_name() {
    setup

    cat > "$TEST_ENV_DIR/test_lib_name.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"

get_lib_name "https://github.com/user/my-library.git"
get_lib_name "https://github.com/user/another-lib"
get_lib_name "git@github.com:user/ssh-lib.git"
EOF

    output=$(bash "$TEST_ENV_DIR/test_lib_name.sh" "$ARTY_SH")

    assert_contains "$output" "my-library"
    assert_contains "$output" "another-lib"
    assert_contains "$output" "ssh-lib"
    teardown
}

# Test: logging functions produce output
test_logging_functions() {
    setup

    cat > "$TEST_ENV_DIR/test_logging.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"

log_info "Info message"
log_success "Success message"
log_warn "Warning message"
log_error "Error message"
EOF

    output=$(bash "$TEST_ENV_DIR/test_logging.sh" "$ARTY_SH" 2>&1)

    assert_contains "$output" "Info message"
    assert_contains "$output" "Success message"
    assert_contains "$output" "Warning message"
    assert_contains "$output" "Error message"
    teardown
}

# Test: init_arty creates directories
test_init_arty_creates_dirs() {
    setup

    export ARTY_HOME="$TEST_ENV_DIR/.arty"

    cat > "$TEST_ENV_DIR/test_init.sh" << 'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
source "${2}"
init_arty
EOF

    bash "$TEST_ENV_DIR/test_init.sh" "$ARTY_HOME" "$ARTY_SH" 2>/dev/null

    assert_directory_exists "$ARTY_HOME"
    assert_directory_exists "$ARTY_HOME/libs"
    assert_directory_exists "$ARTY_HOME/bin"
    teardown
}

# Test: init_arty is idempotent
test_init_arty_idempotent() {
    setup

    export ARTY_HOME="$TEST_ENV_DIR/.arty"

    cat > "$TEST_ENV_DIR/test_idempotent.sh" << 'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
source "${2}"
init_arty
init_arty
init_arty
echo "success"
EOF

    output=$(bash "$TEST_ENV_DIR/test_idempotent.sh" "$ARTY_HOME" "$ARTY_SH" 2>&1)

    assert_contains "$output" "success"
    assert_directory_exists "$ARTY_HOME"
    teardown
}

# Test: normalize_lib_id is case-insensitive
test_normalize_lib_id_case_insensitive() {
    setup

    cat > "$TEST_ENV_DIR/test_normalize_case.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"

id1=$(normalize_lib_id "https://github.com/User/Repo.git")
id2=$(normalize_lib_id "https://github.com/USER/REPO.git")
id3=$(normalize_lib_id "https://github.com/user/repo")

echo "$id1"
echo "$id2"
echo "$id3"
EOF

    output=$(bash "$TEST_ENV_DIR/test_normalize_case.sh" "$ARTY_SH")

    # All three should be the same
    line1=$(echo "$output" | sed -n '1p')
    line2=$(echo "$output" | sed -n '2p')
    line3=$(echo "$output" | sed -n '3p')

    assert_equals "$line1" "$line2"
    assert_equals "$line2" "$line3"
    teardown
}

# Run all tests
run_tests() {
    log_section "Helpers Tests"

    test_check_yq_detects_missing
    test_is_installed_check
    test_is_installed_not_found
    test_circular_dependency_detection
    test_get_lib_name
    test_logging_functions
    test_init_arty_creates_dirs
    test_init_arty_idempotent
    test_normalize_lib_id_case_insensitive
}

export -f run_tests
