#!/usr/bin/env bash
# Test suite for arty init functionality


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



# Test: arty init creates arty.yml
test_init_creates_config() {
    setup
    
    bash "$ARTY_SH" init test-project 2>&1
    
    assert_file_exists "$TEST_ENV_DIR/arty.yml" "Should create arty.yml file"
    assert_contains "$(cat $TEST_ENV_DIR/arty.yml)" "name: \"test-project\"" "Config should contain project name"

    teardown
}

# Test: arty init creates directory structure
test_init_creates_directories() {
    setup
    
    bash "$ARTY_SH" init test-project 2>&1
    
    assert_directory_exists "$TEST_ENV_DIR/.arty" "Should create .arty directory"
    assert_directory_exists "$TEST_ENV_DIR/.arty/bin" "Should create bin directory"
    assert_directory_exists "$TEST_ENV_DIR/.arty/libs" "Should create libs directory"

    teardown
}

# Test: arty init fails if arty.yml exists
test_init_fails_if_config_exists() {
    setup
    
    echo "existing" > "$TEST_ENV_DIR/arty.yml"
    output=$(bash "$ARTY_SH" init test-project 2>&1 || true)
    
    assert_contains "$output" "already exists" "Should report that config already exists"

    teardown
}

# Test: arty init uses current directory name as default
test_init_uses_directory_name() {
    setup
    
    # Create subdirectory and init there
    mkdir -p "$TEST_ENV_DIR/my-cool-project"
    cd "$TEST_ENV_DIR/my-cool-project"
    
    # Unset ARTY_CONFIG_FILE so it uses the default relative path
    unset ARTY_CONFIG_FILE
    
    bash "$ARTY_SH" init 2>&1
    
    assert_file_exists "$TEST_ENV_DIR/my-cool-project/arty.yml" "Should create arty.yml in subdirectory"
    assert_contains "$(cat $TEST_ENV_DIR/my-cool-project/arty.yml)" "my-cool-project" "Should use directory name as project name"

    teardown
}

# Test: arty init creates valid YAML structure
test_init_creates_valid_yaml() {
    setup
    
    bash "$ARTY_SH" init test-project 2>&1
    
    # Check for required fields
    assert_contains "$(cat $TEST_ENV_DIR/arty.yml)" "name:" "Should have name field"
    assert_contains "$(cat $TEST_ENV_DIR/arty.yml)" "version:" "Should have version field"
    assert_contains "$(cat $TEST_ENV_DIR/arty.yml)" "description:" "Should have description field"
    assert_contains "$(cat $TEST_ENV_DIR/arty.yml)" "license:" "Should have license field"
    assert_contains "$(cat $TEST_ENV_DIR/arty.yml)" "references:" "Should have references field"
    assert_contains "$(cat $TEST_ENV_DIR/arty.yml)" "main:" "Should have main field"
    assert_contains "$(cat $TEST_ENV_DIR/arty.yml)" "scripts:" "Should have scripts field"

    teardown
}

# Test: arty init sets default version
test_init_sets_default_version() {
    setup
    
    bash "$ARTY_SH" init test-project 2>&1
    
    assert_contains "$(cat $TEST_ENV_DIR/arty.yml)" "version: \"0.1.0\"" "Should set default version to 0.1.0"

    teardown
}

# Test: arty init sets MIT license by default
test_init_sets_mit_license() {
    setup
    
    bash "$ARTY_SH" init test-project 2>&1
    
    assert_contains "$(cat $TEST_ENV_DIR/arty.yml)" "license: \"MIT\"" "Should set default license to MIT"

    teardown
}

# Run all tests
run_tests() {
    log_section "Init Functionality Tests"
    
    test_init_creates_config
    test_init_creates_directories
    test_init_fails_if_config_exists
    test_init_uses_directory_name
    test_init_creates_valid_yaml
    test_init_sets_default_version
    test_init_sets_mit_license

}

export -f run_tests
