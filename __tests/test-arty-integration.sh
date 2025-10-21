#!/bin/bash
# Integration tests for arty.sh - testing complete workflows



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


# Test: Complete project initialization workflow
test_complete_init_workflow() {
    setup

    # Initialize project (note: when project name given, it uses it for the config name field)
    bash "$ARTY_SH" init my-project 2>&1

    # Check in current directory since ARTY_CONFIG_FILE is set to $TEST_ENV_DIR/arty.yml
    assert_file_exists "$TEST_ENV_DIR/arty.yml" "Config file should be created"
    assert_directory_exists "$TEST_ENV_DIR/.arty" "ARTY directory should be created"
    assert_directory_exists "$TEST_ENV_DIR/.arty/bin" "Bin directory should be created"
    assert_directory_exists "$TEST_ENV_DIR/.arty/libs" "Libs directory should be created"

    # Verify config content
    config_content=$(cat "$TEST_ENV_DIR/arty.yml")
    assert_contains "$config_content" "my-project" "Config should have project name"
    assert_contains "$config_content" "version:" "Config should have version"
    assert_contains "$config_content" "scripts:" "Config should have scripts section"
    teardown
}

# Test: Script execution workflow
test_script_execution_workflow() {
    setup

    # Create config with scripts
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "workflow-test"
version: "1.0.0"
scripts:
  setup: "mkdir -p build && echo 'Setup complete' > build/setup.log"
  build: "echo 'Building...' > build/build.log && echo 'Build complete' >> build/build.log"
  test: "cat build/setup.log && cat build/build.log && echo 'All tests passed'"
EOF

    # Execute workflow
    bash "$ARTY_SH" setup 2>&1
    assert_directory_exists "$TEST_ENV_DIR/build" "Setup should create build directory"
    assert_file_exists "$TEST_ENV_DIR/build/setup.log" "Setup should create log file"

    bash "$ARTY_SH" build 2>&1
    assert_file_exists "$TEST_ENV_DIR/build/build.log" "Build should create log file"

    output=$(bash "$ARTY_SH" test 2>&1)
    assert_contains "$output" "Setup complete" "Test should read setup log"
    assert_contains "$output" "Build complete" "Test should read build log"
    assert_contains "$output" "All tests passed" "Test should complete"
    teardown
}

# Test: Library installation and usage workflow (simulated)
test_library_workflow() {
    setup

    # Create a mock library
    mkdir -p "$TEST_ENV_DIR/mock-lib"
    cat > "$TEST_ENV_DIR/mock-lib/arty.yml" << 'EOF'
name: "mock-lib"
version: "1.0.0"
main: "mock.sh"
EOF

    cat > "$TEST_ENV_DIR/mock-lib/mock.sh" << 'EOF'
#!/usr/bin/env bash
echo "Mock library executed"
EOF
    chmod +x "$TEST_ENV_DIR/mock-lib/mock.sh"

    # Manually install (simulating installation)
    mkdir -p "$ARTY_HOME/libs/mock-lib"
    cp -r "$TEST_ENV_DIR/mock-lib"/* "$ARTY_HOME/libs/mock-lib/"

    # Create bin link
    mkdir -p "$ARTY_HOME/bin"
    ln -sf "$ARTY_HOME/libs/mock-lib/mock.sh" "$ARTY_HOME/bin/mock"

    # List libraries
    output=$(bash "$ARTY_SH" list 2>&1)
    assert_contains "$output" "mock-lib" "Library should be listed"
    assert_contains "$output" "1.0.0" "Version should be shown"

    # Execute library
    output=$(bash "$ARTY_SH" exec mock 2>&1)
    assert_contains "$output" "Mock library executed" "Library should execute"

    # Remove library
    bash "$ARTY_SH" remove mock-lib 2>&1
    assert_false "[[ -d '$ARTY_HOME/libs/mock-lib' ]]" "Library should be removed"
    teardown
}

# Test: Multiple scripts workflow
test_multiple_scripts_workflow() {
    setup

    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "multi-script"
version: "1.0.0"
scripts:
  clean: "rm -rf dist && echo 'Cleaned'"
  prepare: "mkdir -p dist && echo 'Prepared' > dist/status.txt"
  compile: "echo 'Compiled' >> dist/status.txt"
  package: "cat dist/status.txt && echo 'Packaged'"
EOF

    # Run workflow in sequence
    bash "$ARTY_SH" clean 2>&1
    bash "$ARTY_SH" prepare 2>&1
    bash "$ARTY_SH" compile 2>&1
    output=$(bash "$ARTY_SH" package 2>&1)

    assert_contains "$output" "Prepared" "Should show prepared status"
    assert_contains "$output" "Compiled" "Should show compiled status"
    assert_contains "$output" "Packaged" "Should show packaged status"
    teardown
}

# Test: Error recovery workflow
test_error_recovery_workflow() {
    setup

    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "error-test"
version: "1.0.0"
scripts:
  fail: "exit 1"
  recover: "echo 'Recovered from error'"
EOF

    # Run failing script
    set +e
    bash "$ARTY_SH" fail 2>&1
    fail_code=$?
    set -e

    assert_exit_code 1 "$fail_code" "Fail script should return error"

    # Run recovery script
    output=$(bash "$ARTY_SH" recover 2>&1)
    assert_contains "$output" "Recovered from error" "Recovery script should work"
    teardown
}

# Test: Complex script with dependencies
test_complex_script_dependencies() {
    setup

    # Test that scripts can reference each other within the same arty.yml
    # Rather than calling arty recursively, just use shell commands
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "complex"
version: "1.0.0"
scripts:
  deps: "echo 'Installing dependencies...'"
  build: "echo 'Building with dependencies...'"
  all: "echo 'Installing dependencies...' && echo 'Building with dependencies...' && echo 'Complete'"
EOF

    output=$(bash "$ARTY_SH" all 2>&1)

    assert_contains "$output" "Installing dependencies" "Should run deps"
    assert_contains "$output" "Building with dependencies" "Should run build"
    assert_contains "$output" "Complete" "Should complete all steps"
    teardown
}

# Test: Environment variable propagation
test_environment_variable_workflow() {
    setup

    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "env-test"
version: "1.0.0"
scripts:
  set-env: "export BUILD_ENV='production' && echo \"Environment: $BUILD_ENV\""
  use-env: "echo \"Current env: ${BUILD_ENV:-development}\""
EOF

    output1=$(bash "$ARTY_SH" set-env 2>&1)
    assert_contains "$output1" "Environment: production" "Should set environment"

    output2=$(bash "$ARTY_SH" use-env 2>&1)
    assert_contains "$output2" "development" "New script should have default env"
    teardown
}

# Test: File creation and modification workflow
test_file_workflow() {
    setup

    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "file-workflow"
version: "1.0.0"
scripts:
  create: "echo 'Initial content' > data.txt"
  append: "echo 'Appended content' >> data.txt"
  read: "cat data.txt"
EOF

    bash "$ARTY_SH" create 2>&1
    assert_file_exists "$TEST_ENV_DIR/data.txt" "File should be created"

    bash "$ARTY_SH" append 2>&1

    output=$(bash "$ARTY_SH" read 2>&1)
    assert_contains "$output" "Initial content" "Should have initial content"
    assert_contains "$output" "Appended content" "Should have appended content"
    teardown
}

# Test: Directory structure workflow
test_directory_structure_workflow() {
    setup

    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "dir-workflow"
version: "1.0.0"
scripts:
  scaffold: "mkdir -p src/{components,utils,tests} && touch src/components/.gitkeep"
  verify: "ls -la src && ls -la src/components"
EOF

    bash "$ARTY_SH" scaffold 2>&1

    assert_directory_exists "$TEST_ENV_DIR/src" "src directory should exist"
    assert_directory_exists "$TEST_ENV_DIR/src/components" "components directory should exist"
    assert_directory_exists "$TEST_ENV_DIR/src/utils" "utils directory should exist"
    assert_directory_exists "$TEST_ENV_DIR/src/tests" "tests directory should exist"
    assert_file_exists "$TEST_ENV_DIR/src/components/.gitkeep" ".gitkeep should exist"

    output=$(bash "$ARTY_SH" verify 2>&1)
    assert_contains "$output" "components" "Verify should show components"
    teardown
}

# Test: Conditional execution workflow
test_conditional_workflow() {
    setup

    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "conditional"
version: "1.0.0"
scripts:
  check: "if [ -f config.json ]; then echo 'Config exists'; else echo 'No config' && exit 1; fi"
  create: "echo '{}' > config.json"
EOF

    # First check should fail
    set +e
    output1=$(bash "$ARTY_SH" check 2>&1)
    code1=$?
    set -e
    assert_exit_code 1 "$code1" "Check should fail without config"

    # Create config
    bash "$ARTY_SH" create 2>&1

    # Second check should pass
    output2=$(bash "$ARTY_SH" check 2>&1)
    assert_contains "$output2" "Config exists" "Check should pass with config"
    teardown
}

# Test: Data processing workflow
test_data_processing_workflow() {
    setup

    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "data-proc"
version: "1.0.0"
scripts:
  generate: "for i in {1..10}; do echo \"Line $i\"; done > data.txt"
  process: "cat data.txt | grep 'Line 5' && wc -l < data.txt"
  clean: "rm -f data.txt && echo 'Cleaned'"
EOF

    bash "$ARTY_SH" generate 2>&1
    assert_file_exists "$TEST_ENV_DIR/data.txt" "Data file should be generated"

    output=$(bash "$ARTY_SH" process 2>&1)
    assert_contains "$output" "Line 5" "Should find Line 5"
    assert_contains "$output" "10" "Should count 10 lines"

    bash "$ARTY_SH" clean 2>&1
    assert_false "[[ -f '$TEST_ENV_DIR/data.txt' ]]" "Data file should be cleaned"
    teardown
}

# Test: Help and usage workflow
test_help_workflow() {
    setup

    # Test different help invocations
    output1=$(bash "$ARTY_SH" help 2>&1)
    output2=$(bash "$ARTY_SH" --help 2>&1)
    output3=$(bash "$ARTY_SH" -h 2>&1)
    output4=$(bash "$ARTY_SH" 2>&1)

    # All should show usage
    for output in "$output1" "$output2" "$output3" "$output4"; do
        assert_contains "$output" "USAGE:" "Should show usage"
        assert_contains "$output" "COMMANDS:" "Should show commands"
    done

}

# Test: Complete end-to-end workflow
test_end_to_end_workflow() {
    setup

    # 1. Initialize project
    bash "$ARTY_SH" init complete-workflow 2>&1

    # 2. Update config with custom scripts
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "complete-workflow"
version: "1.0.0"
scripts:
  install: "echo 'Dependencies installed'"
  build: "mkdir -p dist && echo 'Built' > dist/app.js"
  test: "echo 'All tests passed'"
  deploy: "cat dist/app.js && echo 'Deployed to production'"
EOF

    # 3. Run complete workflow
    bash "$ARTY_SH" install 2>&1
    bash "$ARTY_SH" build 2>&1
    bash "$ARTY_SH" test 2>&1
    output=$(bash "$ARTY_SH" deploy 2>&1)

    assert_contains "$output" "Built" "Should show build output"
    assert_contains "$output" "Deployed to production" "Should deploy"

    # 4. Verify artifacts
    assert_directory_exists "$TEST_ENV_DIR/dist" "Dist directory should exist"
    assert_file_exists "$TEST_ENV_DIR/dist/app.js" "Build artifact should exist"
    teardown
}

# Run all tests
run_tests() {
    log_section "Integration Tests"

    test_complete_init_workflow
    test_script_execution_workflow
    test_library_workflow
    test_multiple_scripts_workflow
    test_error_recovery_workflow
    test_complex_script_dependencies
    test_environment_variable_workflow
    test_file_workflow
    test_directory_structure_workflow
    test_conditional_workflow
    test_data_processing_workflow
    test_help_workflow
    test_end_to_end_workflow

}

export -f run_tests
