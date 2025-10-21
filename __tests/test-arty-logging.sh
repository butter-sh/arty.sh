#!/bin/bash
# Test suite for arty logging and output functions

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

# Test: log_info produces output
test_log_info_output() {
  setup

  cat >"$TEST_ENV_DIR/test_log_info.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
log_info "This is an info message"
EOF

  output=$(bash "$TEST_ENV_DIR/test_log_info.sh" "$ARTY_SH" 2>&1)

  assert_contains "$output" "INFO" "Should contain INFO label"
  assert_contains "$output" "This is an info message" "Should contain info message"
  teardown
}

# Test: log_success produces output
test_log_success_output() {
  setup

  cat >"$TEST_ENV_DIR/test_log_success.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
log_success "Operation succeeded"
EOF

  output=$(bash "$TEST_ENV_DIR/test_log_success.sh" "$ARTY_SH" 2>&1)

  assert_contains "$output" "SUCCESS" "Should contain SUCCESS label"
  assert_contains "$output" "Operation succeeded" "Should contain success message"
  teardown
}

# Test: log_warn produces output
test_log_warn_output() {
  setup

  cat >"$TEST_ENV_DIR/test_log_warn.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
log_warn "This is a warning"
EOF

  output=$(bash "$TEST_ENV_DIR/test_log_warn.sh" "$ARTY_SH" 2>&1)

  assert_contains "$output" "WARN" "Should contain WARN label"
  assert_contains "$output" "This is a warning" "Should contain warning message"
  teardown
}

# Test: log_error produces output
test_log_error_output() {
  setup

  cat >"$TEST_ENV_DIR/test_log_error.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
log_error "This is an error"
EOF

  output=$(bash "$TEST_ENV_DIR/test_log_error.sh" "$ARTY_SH" 2>&1)

  assert_contains "$output" "ERROR" "Should contain ERROR label"
  assert_contains "$output" "This is an error" "Should contain error message"
  teardown
}

# Test: logging functions handle empty messages
test_logging_empty_messages() {
  setup

  cat >"$TEST_ENV_DIR/test_empty_log.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
log_info ""
log_success ""
log_warn ""
log_error ""
echo "COMPLETED"
EOF

  output=$(bash "$TEST_ENV_DIR/test_empty_log.sh" "$ARTY_SH" 2>&1)

  assert_contains "$output" "COMPLETED" "Should complete without errors"
  teardown
}

# Test: logging functions handle special characters
test_logging_special_characters() {
  setup

  cat >"$TEST_ENV_DIR/test_special_chars.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
log_info "Message with special chars: !@#$%^&*()"
log_success "Success with quotes: \"quoted\" and 'single'"
log_warn "Warning with newline:\nNew line"
EOF

  output=$(bash "$TEST_ENV_DIR/test_special_chars.sh" "$ARTY_SH" 2>&1)

  assert_contains "$output" "!@#$%^&*()" "Should handle special characters"
  assert_contains "$output" "quoted" "Should handle double quotes"
  assert_contains "$output" "single" "Should handle single quotes"
  teardown
}

# Test: logging functions handle long messages
test_logging_long_messages() {
  setup

  cat >"$TEST_ENV_DIR/test_long_log.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
long_msg=$(printf 'A%.0s' {1..500})
log_info "$long_msg"
echo "DONE"
EOF

  output=$(bash "$TEST_ENV_DIR/test_long_log.sh" "$ARTY_SH" 2>&1)

  assert_contains "$output" "DONE" "Should handle long messages without crashing"
  teardown
}

# Test: logging functions handle multiline messages
test_logging_multiline_messages() {
  setup

  cat >"$TEST_ENV_DIR/test_multiline_log.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
log_info "Line 1
Line 2
Line 3"
EOF

  output=$(bash "$TEST_ENV_DIR/test_multiline_log.sh" "$ARTY_SH" 2>&1)

  assert_contains "$output" "Line 1" "Should handle multiline message - line 1"
  teardown
}

# Test: logging functions output to stderr
test_logging_stderr() {
  setup

  cat >"$TEST_ENV_DIR/test_stderr.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
log_info "Info to stderr" 2>&1
log_error "Error to stderr" 2>&1
EOF

  output=$(bash "$TEST_ENV_DIR/test_stderr.sh" "$ARTY_SH")

  # Both should be captured when stderr is redirected to stdout
  assert_contains "$output" "Info to stderr" "Info should output to stderr"
  assert_contains "$output" "Error to stderr" "Error should output to stderr"
  teardown
}

# Test: logging functions handle unicode characters
test_logging_unicode() {
  setup

  cat >"$TEST_ENV_DIR/test_unicode.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
log_info "Unicode: 你好 🚀 ☀️"
EOF

  output=$(bash "$TEST_ENV_DIR/test_unicode.sh" "$ARTY_SH" 2>&1)

  # Should not crash with unicode
  assert_contains "$output" "INFO" "Should handle unicode characters"
  teardown
}

# Test: logging functions handle backticks
test_logging_backticks() {
  setup

  cat >"$TEST_ENV_DIR/test_backticks.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
log_info "Message with \`backticks\`"
EOF

  output=$(bash "$TEST_ENV_DIR/test_backticks.sh" "$ARTY_SH" 2>&1)

  assert_contains "$output" "backticks" "Should handle backticks"
  teardown
}

# Test: logging functions handle variables
test_logging_variables() {
  setup

  cat >"$TEST_ENV_DIR/test_vars_log.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
VAR="test value"
log_info "Variable: $VAR"
log_success "Another variable: ${VAR}"
EOF

  output=$(bash "$TEST_ENV_DIR/test_vars_log.sh" "$ARTY_SH" 2>&1)

  assert_contains "$output" "test value" "Should expand variables"
  teardown
}

# Test: logging output format consistency
test_logging_format_consistency() {
  setup

  cat >"$TEST_ENV_DIR/test_format.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
log_info "Message 1"
log_success "Message 2"
log_warn "Message 3"
log_error "Message 4"
EOF

  output=$(bash "$TEST_ENV_DIR/test_format.sh" "$ARTY_SH" 2>&1)

  # Check that each log type is present
  assert_contains "$output" "[INFO]" "Info format should be present"
  assert_contains "$output" "[SUCCESS]" "Success format should be present"
  assert_contains "$output" "[WARN]" "Warn format should be present"
  assert_contains "$output" "[ERROR]" "Error format should be present"
  teardown
}

# Test: show_usage produces comprehensive help
test_show_usage_comprehensive() {
  setup

  output=$(bash "$ARTY_SH" help 2>&1)

  assert_contains "$output" "USAGE:" "Should have USAGE section"
  assert_contains "$output" "COMMANDS:" "Should have COMMANDS section"
  assert_contains "$output" "EXAMPLES:" "Should have EXAMPLES section"
  assert_contains "$output" "install" "Should document install command"
  assert_contains "$output" "deps" "Should document deps command"
  assert_contains "$output" "list" "Should document list command"
  assert_contains "$output" "remove" "Should document remove command"
  assert_contains "$output" "init" "Should document init command"
  assert_contains "$output" "exec" "Should document exec command"
  assert_contains "$output" "source" "Should document source command"
  teardown
}

# Test: show_usage includes project structure
test_show_usage_project_structure() {
  setup

  output=$(bash "$ARTY_SH" help 2>&1)

  assert_contains "$output" "PROJECT STRUCTURE:" "Should include project structure section"
  assert_contains "$output" ".arty" "Should mention .arty directory"
  assert_contains "$output" "libs" "Should mention libs directory"
  assert_contains "$output" "bin" "Should mention bin directory"
  teardown
}

# Test: show_usage includes environment variables
test_show_usage_environment() {
  setup

  output=$(bash "$ARTY_SH" help 2>&1)

  assert_contains "$output" "ENVIRONMENT:" "Should include environment section"
  assert_contains "$output" "ARTY_HOME" "Should mention ARTY_HOME variable"
  teardown
}

# Run all tests
run_tests() {
  log_section "Logging and Output Tests"

  test_log_info_output
  test_log_success_output
  test_log_warn_output
  test_log_error_output
  test_logging_empty_messages
  test_logging_special_characters
  test_logging_long_messages
  test_logging_multiline_messages
  test_logging_stderr
  test_logging_unicode
  test_logging_backticks
  test_logging_variables
  test_logging_format_consistency
  test_show_usage_comprehensive
  test_show_usage_project_structure
  test_show_usage_environment

}

export -f run_tests
