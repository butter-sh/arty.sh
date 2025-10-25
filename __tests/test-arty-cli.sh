#!/bin/bash
# Test suite for arty CLI interface and commands

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

# Test: arty without arguments shows usage
test_no_args_shows_usage() {
  setup

  output=$(bash "$ARTY_SH" 2>&1)

  assert_contains "$output" "USAGE:" "Should show usage"
  assert_contains "$output" "COMMANDS:" "Should show commands"
  teardown
}

# Test: arty help shows usage
test_help_command() {
  setup

  output=$(bash "$ARTY_SH" help 2>&1)

  assert_contains "$output" "USAGE:" "Should show usage"
  assert_contains "$output" "COMMANDS:" "Should show commands"
  teardown
}

# Test: arty --help shows usage
test_help_flag() {
  setup

  output=$(bash "$ARTY_SH" --help 2>&1)

  assert_contains "$output" "USAGE:" "Should show usage"
  teardown
}

# Test: arty -h shows usage
test_help_short_flag() {
  setup

  output=$(bash "$ARTY_SH" -h 2>&1)

  assert_contains "$output" "USAGE:" "Should show usage"
  teardown
}

# Test: unknown command shows error
test_unknown_command() {
  setup

  set +e
  output=$(bash "$ARTY_SH" nonexistent-command 2>&1)
  exit_code=$?
  set -e

  # Should either show error or try to run as script
  # Since no arty.yml exists, should show error
  assert_true "[[ $exit_code -ne 0 ]]" "Unknown command should fail"
  teardown
}

# Test: remove command requires library name
test_remove_requires_name() {
  setup

  output=$(bash "$ARTY_SH" remove 2>&1 || true)

  assert_contains "$output" "Library name required" "Should require library name"
  teardown
}

# Test: rm alias works
test_rm_alias() {
  setup

  output=$(bash "$ARTY_SH" rm 2>&1 || true)

  assert_contains "$output" "Library name required" "Should require library name"
  teardown
}

# Test: remove non-existent library fails
test_remove_nonexistent() {
  setup

  mkdir -p "$ARTY_HOME/libs"
  output=$(bash "$ARTY_SH" remove nonexistent 2>&1 || true)

  assert_contains "$output" "not found" "Should not found"
  teardown
}

# Test: source command requires library name
test_source_requires_name() {
  setup

  output=$(bash "$ARTY_SH" source 2>&1 || true)

  assert_contains "$output" "Library name required" "Should require library name"
  teardown
}

# Test: usage shows all major commands
test_usage_shows_commands() {
  setup

  output=$(bash "$ARTY_SH" help 2>&1)

  # Check for all major commands
  assert_contains "$output" "install" "Should show install"
  assert_contains "$output" "deps" "Should show deps"
  assert_contains "$output" "list" "Should show list"
  assert_contains "$output" "remove" "Should show remove"
  assert_contains "$output" "init" "Should show init"
  assert_contains "$output" "source" "Should show source"
  assert_contains "$output" "exec" "Should show exec"
  assert_contains "$output" "help" "Should show help"
  teardown
}

# Test: usage shows examples
test_usage_shows_examples() {
  setup

  output=$(bash "$ARTY_SH" help 2>&1)

  assert_contains "$output" "EXAMPLES:" "Should show examples"
  teardown
}

# Test: usage shows environment variables
test_usage_shows_environment() {
  setup

  output=$(bash "$ARTY_SH" help 2>&1)

  assert_contains "$output" "ENVIRONMENT:" "Should show environment"
  assert_contains "$output" "ARTY_HOME" "Should show arty home"
  teardown
}

# Test: usage shows project structure
test_usage_shows_structure() {
  setup

  output=$(bash "$ARTY_SH" help 2>&1)

  assert_contains "$output" "PROJECT STRUCTURE:" "Should show project structure"
  teardown
}

# Test: list works with ls alias
test_list_ls_alias() {
  setup

  mkdir -p "$ARTY_HOME/libs"
  output1=$(bash "$ARTY_SH" list 2>&1)
  output2=$(bash "$ARTY_SH" ls 2>&1)

  # Both should produce similar output
  assert_contains "$output1" "libraries" "Should show libraries"
  assert_contains "$output2" "libraries" "Should show libraries"
  teardown
}

# Test: command parsing is case-sensitive
test_command_case_sensitive() {
  setup

  # HELP (uppercase) should not work
  set +e
  output=$(bash "$ARTY_SH" HELP 2>&1)
  exit_code=$?
  set -e

  # Should fail as unknown command (unless there's a script named HELP)
  assert_true "[[ $exit_code -ne 0 ]]" "Case sensitive command should fail"
  teardown
}

# Run all tests
run_tests() {
  log_section "CLI Tests"

  test_no_args_shows_usage
  test_help_command
  test_help_flag
  test_help_short_flag
  test_unknown_command
  test_remove_requires_name
  test_rm_alias
  test_remove_nonexistent
  test_source_requires_name
  test_usage_shows_commands
  test_usage_shows_examples
  test_usage_shows_environment
  test_usage_shows_structure
  test_list_ls_alias
  test_command_case_sensitive
}

export -f run_tests
