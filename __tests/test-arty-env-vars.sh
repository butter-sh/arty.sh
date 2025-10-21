#!/usr/bin/env bash

# test-arty-env-vars.sh - Test environment variable loading functionality
# Tests the new env vars feature for arty.sh

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
  unset APP_ENV LOG_LEVEL DEBUG API_URL
  unset ARTY_ENV
}

# Test: Load default environment variables
test_load_default_env_vars() {
  setup

  # Create test arty.yml with envs section
  cat >arty.yml <<'EOF'
name: "test-project"
version: "1.0.0"

envs:
  default:
    APP_ENV: "default"
    LOG_LEVEL: "info"
    DEBUG: "false"

scripts:
  test: "echo 'test'"
EOF

  # Run arty command to trigger env loading
  output=$($ARTY_SH help 2>&1)

  # Check if environment variables were set
  assert_equals "$APP_ENV" "default" "APP_ENV should be set to default"
  assert_equals "$LOG_LEVEL" "info" "LOG_LEVEL should be set to info"
  assert_equals "$DEBUG" "false" "DEBUG should be set to false"

  teardown
}

# Test: Load development environment variables
test_load_development_env_vars() {
  setup

  # Create test arty.yml with multiple envs
  cat >arty.yml <<'EOF'
name: "test-project"
version: "1.0.0"

envs:
  default:
    APP_ENV: "default"
    LOG_LEVEL: "info"
  development:
    APP_ENV: "development"
    LOG_LEVEL: "debug"
    DEBUG: "true"
    API_URL: "http://localhost:3000"

scripts:
  test: "echo 'test'"
EOF

  # Run with ARTY_ENV=development
  ARTY_ENV=development $ARTY_SH help 2>&1 >/dev/null

  # Check if development environment variables were set
  assert_equals "$APP_ENV" "development" "APP_ENV should be set to development"
  assert_equals "$LOG_LEVEL" "debug" "LOG_LEVEL should be set to debug"
  assert_equals "$DEBUG" "true" "DEBUG should be set to true"
  assert_equals "$API_URL" "http://localhost:3000" "API_URL should be set"

  teardown
}

# Test: Load production environment variables
test_load_production_env_vars() {
  setup

  # Create test arty.yml
  cat >arty.yml <<'EOF'
name: "test-project"
version: "1.0.0"

envs:
  default:
    APP_ENV: "default"
    LOG_LEVEL: "info"
  production:
    APP_ENV: "production"
    LOG_LEVEL: "error"
    DEBUG: "false"

scripts:
  test: "echo 'test'"
EOF

  # Run with ARTY_ENV=production
  ARTY_ENV=production $ARTY_SH help 2>&1 >/dev/null

  # Check if production environment variables were set
  assert_equals "$APP_ENV" "production" "APP_ENV should be set to production"
  assert_equals "$LOG_LEVEL" "error" "LOG_LEVEL should be set to error"
  assert_equals "$DEBUG" "false" "DEBUG should be set to false"

  teardown
}

# Test: No envs section in arty.yml
test_no_envs_section() {
  setup

  # Create arty.yml without envs section
  cat >arty.yml <<'EOF'
name: "test-project"
version: "1.0.0"

scripts:
  test: "echo 'test'"
EOF

  # Run arty - should not fail
  output=$($ARTY_SH help 2>&1)
  exit_code=$?

  assert_equals "$exit_code" "0" "Should exit successfully without envs section"

  teardown
}

# Test: Environment variables override
test_env_vars_override() {
  setup

  # Create test arty.yml
  cat >arty.yml <<'EOF'
name: "test-project"
version: "1.0.0"

envs:
  default:
    APP_ENV: "default"
    LOG_LEVEL: "info"
    SHARED_VAR: "from_default"
  development:
    APP_ENV: "development"
    LOG_LEVEL: "debug"
    SHARED_VAR: "from_development"

scripts:
  test: "echo 'test'"
EOF

  # Run with development environment
  ARTY_ENV=development $ARTY_SH help 2>&1 >/dev/null

  # Check that development overrides default
  assert_equals "$APP_ENV" "development" "APP_ENV should be development"
  assert_equals "$SHARED_VAR" "from_development" "SHARED_VAR should be overridden by development"

  teardown
}

# Test: Pre-existing environment variables are not overridden by default
test_preserve_existing_env_vars() {
  setup

  # Set environment variable before running arty
  export APP_ENV="pre_existing"

  # Create test arty.yml
  cat >arty.yml <<'EOF'
name: "test-project"
version: "1.0.0"

envs:
  default:
    APP_ENV: "default"
    LOG_LEVEL: "info"

scripts:
  test: "echo 'test'"
EOF

  # Run arty
  $ARTY_SH help 2>&1 >/dev/null

  # Check that pre-existing variable was preserved (for default env only)
  assert_equals "$APP_ENV" "pre_existing" "Pre-existing APP_ENV should be preserved in default env"
  assert_equals "$LOG_LEVEL" "info" "LOG_LEVEL should still be set"

  teardown
}

# Test: Invalid YAML handling
test_invalid_yaml() {
  setup

  # Create invalid YAML
  cat >arty.yml <<'EOF'
name: "test-project"
version: "1.0.0"
envs:
  default:
    APP_ENV: "default
    - broken yaml
EOF

  # Run arty - should handle gracefully
  output=$($ARTY_SH help 2>&1)
  exit_code=$?

  # Should not crash, just warn
  assert_contains "$output" "WARN" "Should warn about invalid YAML"

  teardown
}

# Test: Environment variables are available in scripts
test_env_vars_in_scripts() {
  setup

  # Create test arty.yml with script that uses env vars
  cat >arty.yml <<'EOF'
name: "test-project"
version: "1.0.0"

envs:
  default:
    TEST_VAR: "hello_world"

scripts:
  print_var: "echo $TEST_VAR"
EOF

  # Run script and capture output
  output=$($ARTY_SH print_var 2>/dev/null)

  assert_equals "$output" "hello_world" "Script should have access to env vars"

  teardown
}

# Test: Loading message appears
test_loading_message() {
  setup

  # Create test arty.yml
  cat >arty.yml <<'EOF'
name: "test-project"
version: "1.0.0"

envs:
  default:
    APP_ENV: "default"

scripts:
  test: "echo 'test'"
EOF

  # Run arty and capture stderr
  output=$($ARTY_SH help 2>&1)

  assert_contains "$output" "Loading environment variables from 'default' environment" \
    "Should show loading message"

  teardown
}

# Test: Multiple environments defined
test_multiple_environments() {
  setup

  # Create arty.yml with three environments
  cat >arty.yml <<'EOF'
name: "test-project"
version: "1.0.0"

envs:
  default:
    ENV_NAME: "default"
  staging:
    ENV_NAME: "staging"
    STAGING_ONLY: "yes"
  production:
    ENV_NAME: "production"
    PROD_ONLY: "yes"

scripts:
  test: "echo 'test'"
EOF

  # Test staging
  ARTY_ENV=staging $ARTY_SH help 2>&1 >/dev/null
  assert_equals "$ENV_NAME" "staging" "Should load staging environment"
  assert_equals "$STAGING_ONLY" "yes" "Should have staging-only variable"

  # Clear variables
  unset ENV_NAME STAGING_ONLY PROD_ONLY

  # Test production
  ARTY_ENV=production $ARTY_SH help 2>&1 >/dev/null
  assert_equals "$ENV_NAME" "production" "Should load production environment"
  assert_equals "$PROD_ONLY" "yes" "Should have production-only variable"

  teardown
}

run_tests() {
  # Pattern to match function names
  PATTERN=" test_"

  # echo "$0"
  # Source the current file to load its functions
  # source "$0"
  # declare -F

  # Get a list of function names matching the pattern
  FUNCTIONS=$(declare -F | grep "$PATTERN" | awk '{print $3}')

  # echo $FUNCTIONS
 
  # Execute each function
  for func in $FUNCTIONS; do
    # echo "Executing: $func"
    "$func"
  done
}

export -f run_tests
