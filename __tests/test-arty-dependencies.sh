#!/bin/bash
# Test suite for arty dependency management and circular dependency detection



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


# Test: mark_installing and is_installing work correctly
test_dependency_tracking() {
    setup

    cat > "$TEST_ENV_DIR/test_tracking.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"

# Test marking
mark_installing "lib1"
if is_installing "lib1"; then
    echo "MARKED"
fi

# Test unmarking
unmark_installing "lib1"
if is_installing "lib1"; then
    echo "STILL_MARKED"
else
    echo "UNMARKED"
fi
EOF

    output=$(bash "$TEST_ENV_DIR/test_tracking.sh" "$ARTY_SH")

    assert_contains "$output" "MARKED" "Library should be marked as installing"
    assert_contains "$output" "UNMARKED" "Library should be unmarked after unmark_installing"
    assert_not_contains "$output" "STILL_MARKED" "Library should not be marked after unmarking"
    teardown
}

# Test: is_installing returns false for non-tracked library
test_is_installing_false_for_untracked() {
    setup

    cat > "$TEST_ENV_DIR/test_untracked.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"

if is_installing "untracked-lib"; then
    echo "TRACKED"
else
    echo "NOT_TRACKED"
fi
EOF

    output=$(bash "$TEST_ENV_DIR/test_untracked.sh" "$ARTY_SH")

    assert_contains "$output" "NOT_TRACKED" "Untracked library should not be marked as installing"
    teardown
}

# Test: multiple libraries can be tracked simultaneously
test_multiple_library_tracking() {
    setup

    cat > "$TEST_ENV_DIR/test_multiple.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"

mark_installing "lib1"
mark_installing "lib2"
mark_installing "lib3"

count=0
if is_installing "lib1"; then count=$((count+1)); fi
if is_installing "lib2"; then count=$((count+1)); fi
if is_installing "lib3"; then count=$((count+1)); fi

echo "COUNT:$count"

unmark_installing "lib2"

count2=0
if is_installing "lib1"; then count2=$((count2+1)); fi
if is_installing "lib2"; then count2=$((count2+1)); fi
if is_installing "lib3"; then count2=$((count2+1)); fi

echo "COUNT2:$count2"
EOF

    output=$(bash "$TEST_ENV_DIR/test_multiple.sh" "$ARTY_SH")

    assert_contains "$output" "COUNT:3" "All three libraries should be tracked"
    assert_contains "$output" "COUNT2:2" "Two libraries should remain after unmarking one"
    teardown
}

# Test: is_installed checks directory existence
test_is_installed_directory_check() {
    setup

    mkdir -p "$ARTY_HOME/libs/test-lib"

    cat > "$TEST_ENV_DIR/test_installed.sh" << 'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
source "${2}"

if is_installed "test-lib"; then
    echo "INSTALLED"
else
    echo "NOT_INSTALLED"
fi

if is_installed "nonexistent-lib"; then
    echo "NONEXISTENT_INSTALLED"
else
    echo "NONEXISTENT_NOT_INSTALLED"
fi
EOF

    output=$(bash "$TEST_ENV_DIR/test_installed.sh" "$ARTY_HOME" "$ARTY_SH")

    assert_contains "$output" "INSTALLED" "Existing library should be detected as installed"
    assert_contains "$output" "NONEXISTENT_NOT_INSTALLED" "Non-existent library should not be detected as installed"
    teardown
}

# Test: normalize_lib_id is case-insensitive and removes .git
test_normalize_lib_id_behavior() {
    setup

    cat > "$TEST_ENV_DIR/test_normalize.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"

id1=$(normalize_lib_id "https://github.com/User/Repository.git")
id2=$(normalize_lib_id "https://github.com/USER/REPOSITORY.git")
id3=$(normalize_lib_id "https://github.com/user/repository")

if [[ "$id1" == "$id2" ]] && [[ "$id2" == "$id3" ]]; then
    echo "NORMALIZED_SAME"
else
    echo "NORMALIZED_DIFFERENT"
fi

echo "ID1:$id1"
EOF

    output=$(bash "$TEST_ENV_DIR/test_normalize.sh" "$ARTY_SH")

    assert_contains "$output" "NORMALIZED_SAME" "All variations should normalize to same ID"
    assert_contains "$output" "user/repository" "Normalized ID should be lowercase without .git"
    teardown
}

# Test: get_lib_name extracts correct library name
test_get_lib_name_extraction() {
    setup

    cat > "$TEST_ENV_DIR/test_lib_name.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"

get_lib_name "https://github.com/user/my-awesome-lib.git"
get_lib_name "https://github.com/user/another-lib"
get_lib_name "git@github.com:user/ssh-lib.git"
get_lib_name "https://gitlab.com/group/project-name.git"
EOF

    output=$(bash "$TEST_ENV_DIR/test_lib_name.sh" "$ARTY_SH")

    assert_contains "$output" "my-awesome-lib" "Should extract library name from https URL with .git"
    assert_contains "$output" "another-lib" "Should extract library name from https URL without .git"
    assert_contains "$output" "ssh-lib" "Should extract library name from SSH URL"
    assert_contains "$output" "project-name" "Should extract library name from GitLab URL"
    teardown
}

# Test: circular dependency detection in action
test_circular_dependency_prevention() {
    setup

    cat > "$TEST_ENV_DIR/test_circular.sh" << 'EOF'
#!/usr/bin/env bash
source "${1}"

# Simulate circular dependency
lib_id=$(normalize_lib_id "https://github.com/user/circular-lib.git")

mark_installing "$lib_id"

# Try to install again (should detect circular dependency)
if is_installing "$lib_id"; then
    echo "CIRCULAR_DETECTED"
else
    echo "NO_CIRCULAR"
fi

# Cleanup
unmark_installing "$lib_id"

# Should be clear now
if is_installing "$lib_id"; then
    echo "STILL_CIRCULAR"
else
    echo "CLEARED"
fi
EOF

    output=$(bash "$TEST_ENV_DIR/test_circular.sh" "$ARTY_SH")

    assert_contains "$output" "CIRCULAR_DETECTED" "Should detect when library is already being installed"
    assert_contains "$output" "CLEARED" "Should clear after unmarking"
    assert_not_contains "$output" "STILL_CIRCULAR" "Should not detect circular after clearing"
    teardown
}

# Run all tests
run_tests() {
    log_section "Dependency Management Tests"

    test_dependency_tracking
    test_is_installing_false_for_untracked
    test_multiple_library_tracking
    test_is_installed_directory_check
    test_normalize_lib_id_behavior
    test_get_lib_name_extraction
    test_circular_dependency_prevention

}

export -f run_tests
