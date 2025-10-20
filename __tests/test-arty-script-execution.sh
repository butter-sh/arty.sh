#!/usr/bin/env bash
# Test suite for arty script execution with comprehensive coverage



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


# Test: exec_script executes simple script from arty.yml
test_exec_script_simple() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  hello: "echo 'Hello World'"
EOF
    
    output=$(bash "$ARTY_SH" hello 2>&1)
    
    assert_contains "$output" "Hello World" "Simple script should execute and output text"
    teardown
}

# Test: exec_script with environment variables
test_exec_script_with_env_vars() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  env-test: "export NAME='Arty' && echo \"Hello $NAME\""
EOF
    
    output=$(bash "$ARTY_SH" env-test 2>&1)
    
    assert_contains "$output" "Hello Arty" "Script with environment variables should execute"
    teardown
}

# Test: exec_script with chained commands
test_exec_script_chained_commands() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  chain: "echo 'First' && echo 'Second' && echo 'Third'"
EOF
    
    output=$(bash "$ARTY_SH" chain 2>&1)
    
    assert_contains "$output" "First" "First command should execute"
    assert_contains "$output" "Second" "Second command should execute"
    assert_contains "$output" "Third" "Third command should execute"
    teardown
}

# Test: exec_script with multiline script
test_exec_script_multiline() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  multi: |
    echo "Line 1"
    echo "Line 2"
    echo "Line 3"
EOF
    
    output=$(bash "$ARTY_SH" multi 2>&1)
    
    assert_contains "$output" "Line 1" "Multiline script line 1 should execute"
    assert_contains "$output" "Line 2" "Multiline script line 2 should execute"
    assert_contains "$output" "Line 3" "Multiline script line 3 should execute"
    teardown
}

# Test: exec_script with file operations
test_exec_script_file_operations() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  create: "echo 'test content' > test.txt && cat test.txt"
EOF
    
    output=$(bash "$ARTY_SH" create 2>&1)
    
    assert_contains "$output" "test content" "Script should create and read file"
    assert_file_exists "$TEST_ENV_DIR/test.txt" "File should exist after script execution"
    teardown
}

# Test: exec_script with conditional logic
test_exec_script_conditional() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  conditional: "if [ 1 -eq 1 ]; then echo 'TRUE'; else echo 'FALSE'; fi"
EOF
    
    output=$(bash "$ARTY_SH" conditional 2>&1)
    
    assert_contains "$output" "TRUE" "Conditional script should execute true branch"
    assert_not_contains "$output" "FALSE" "Conditional script should not execute false branch"
    teardown
}

# Test: exec_script with for loop
test_exec_script_loop() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  loop: "for i in 1 2 3; do echo \"Number: $i\"; done"
EOF
    
    output=$(bash "$ARTY_SH" loop 2>&1)
    
    assert_contains "$output" "Number: 1" "Loop should execute iteration 1"
    assert_contains "$output" "Number: 2" "Loop should execute iteration 2"
    assert_contains "$output" "Number: 3" "Loop should execute iteration 3"
    teardown
}

# Test: exec_script error handling
test_exec_script_error_handling() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  error: "exit 1"
EOF
    
    set +e
    output=$(bash "$ARTY_SH" error 2>&1)
    exit_code=$?
    set -e
    
    assert_exit_code 1 "$exit_code" "Script with error should return non-zero exit code"
    teardown
}

# Test: exec_script with function definition and call
test_exec_script_function() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  func: "greet() { echo \"Hello $1\"; }; greet 'Arty'"
EOF
    
    output=$(bash "$ARTY_SH" func 2>&1)
    
    assert_contains "$output" "Hello Arty" "Script with function definition should execute"
    teardown
}

# Test: exec_script with arithmetic operations
test_exec_script_arithmetic() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  math: "echo $((5 + 3))"
EOF
    
    output=$(bash "$ARTY_SH" math 2>&1)
    
    assert_contains "$output" "8" "Arithmetic operation should execute correctly"
    teardown
}

# Test: exec_script with command substitution
test_exec_script_command_substitution() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  subst: "result=$(echo 'substituted'); echo \"Result: $result\""
EOF
    
    output=$(bash "$ARTY_SH" subst 2>&1)
    
    assert_contains "$output" "Result: substituted" "Command substitution should work"
    teardown
}

# Test: exec_script with pipe operations
test_exec_script_pipes() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  pipe: "echo 'hello world' | tr 'a-z' 'A-Z'"
EOF
    
    output=$(bash "$ARTY_SH" pipe 2>&1)
    
    assert_contains "$output" "HELLO WORLD" "Pipe operations should work"
    teardown
}

# Test: exec_script accessing current directory
test_exec_script_current_directory() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  pwd: "basename $(pwd)"
EOF
    
    output=$(bash "$ARTY_SH" pwd 2>&1)
    
    # Should contain the temp directory basename
    assert_true "[[ -n '$output' ]]" "Script should output current directory"
    teardown
}

# Test: exec_script with variable assignment
test_exec_script_variables() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'EOF'
name: "test-project"
version: "1.0.0"
scripts:
  vars: "VAR1='value1'; VAR2='value2'; echo \"$VAR1 and $VAR2\""
EOF
    
    output=$(bash "$ARTY_SH" vars 2>&1)
    
    assert_contains "$output" "value1 and value2" "Variable assignment should work"
    teardown
}

# Test: exec_script with here document
test_exec_script_heredoc() {
    setup
    
    cat > "$TEST_ENV_DIR/arty.yml" << 'OUTER'
name: "test-project"
version: "1.0.0"
scripts:
  heredoc: "cat << 'EOF'\nLine 1\nLine 2\nEOF"
OUTER
    
    output=$(bash "$ARTY_SH" heredoc 2>&1)
    
    assert_contains "$output" "Line 1" "Heredoc should work - line 1"
    assert_contains "$output" "Line 2" "Heredoc should work - line 2"
    teardown
}

# Run all tests
run_tests() {
    log_section "Script Execution Advanced Tests"
    
    test_exec_script_simple
    test_exec_script_with_env_vars
    test_exec_script_chained_commands
    test_exec_script_multiline
    test_exec_script_file_operations
    test_exec_script_conditional
    test_exec_script_loop
    test_exec_script_error_handling
    test_exec_script_function
    test_exec_script_arithmetic
    test_exec_script_command_substitution
    test_exec_script_pipes
    test_exec_script_current_directory
    test_exec_script_variables
    test_exec_script_heredoc

}

export -f run_tests
