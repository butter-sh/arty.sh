#!/bin/bash
# Test suite for arty environment variables feature

# Setup before each test
setup() {
  TEST_ENV_DIR=$(create_test_env)
  export ARTY_HOME="$TEST_ENV_DIR/.arty"
  export ARTY_CONFIG_FILE="$TEST_ENV_DIR/arty.yml"
  cd "$TEST_ENV_DIR"
}

# Test cleanup
teardown() {
  cleanup_test_env
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
  check: "echo APP_ENV=$APP_ENV LOG_LEVEL=$LOG_LEVEL DEBUG=$DEBUG"
EOF

  # Create wrapper script to run arty command
  cat >"$TEST_ENV_DIR/run_test.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
export ARTY_CONFIG_FILE="${2}/arty.yml"
cd "${2}"
source "${3}"
main check
EOF

  # Run arty command and capture the output
  output=$(bash "$TEST_ENV_DIR/run_test.sh" "$ARTY_HOME" "$TEST_ENV_DIR" "$ARTY_SH" 2>/dev/null)

  # Check if environment variables were set in the script output
  assert_contains "$output" "APP_ENV=default" "APP_ENV should be set to default"
  assert_contains "$output" "LOG_LEVEL=info" "LOG_LEVEL should be set to info"
  assert_contains "$output" "DEBUG=false" "DEBUG should be set to false"

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
  check: "echo APP_ENV=$APP_ENV LOG_LEVEL=$LOG_LEVEL DEBUG=$DEBUG API_URL=$API_URL"
EOF

  # Create wrapper script with ARTY_ENV=development
  cat >"$TEST_ENV_DIR/run_test.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
export ARTY_CONFIG_FILE="${2}/arty.yml"
export ARTY_ENV="development"
cd "${2}"
source "${3}"
main check
EOF

  # Run with ARTY_ENV=development
  output=$(bash "$TEST_ENV_DIR/run_test.sh" "$ARTY_HOME" "$TEST_ENV_DIR" "$ARTY_SH" 2>/dev/null)

  # Check if development environment variables were set
  assert_contains "$output" "APP_ENV=development" "APP_ENV should be set to development"
  assert_contains "$output" "LOG_LEVEL=debug" "LOG_LEVEL should be set to debug"
  assert_contains "$output" "DEBUG=true" "DEBUG should be set to true"
  assert_contains "$output" "API_URL=http://localhost:3000" "API_URL should be set"

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
  check: "echo APP_ENV=$APP_ENV LOG_LEVEL=$LOG_LEVEL DEBUG=$DEBUG"
EOF

  # Create wrapper script with ARTY_ENV=production
  cat >"$TEST_ENV_DIR/run_test.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
export ARTY_CONFIG_FILE="${2}/arty.yml"
export ARTY_ENV="production"
cd "${2}"
source "${3}"
main check
EOF

  # Run with ARTY_ENV=production
  output=$(bash "$TEST_ENV_DIR/run_test.sh" "$ARTY_HOME" "$TEST_ENV_DIR" "$ARTY_SH" 2>/dev/null)

  # Check if production environment variables were set
  assert_contains "$output" "APP_ENV=production" "APP_ENV should be set to production"
  assert_contains "$output" "LOG_LEVEL=error" "LOG_LEVEL should be set to error"
  assert_contains "$output" "DEBUG=false" "DEBUG should be set to false"

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

  # Create wrapper script to run help command
  cat >"$TEST_ENV_DIR/run_test.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
export ARTY_CONFIG_FILE="${2}/arty.yml"
cd "${2}"
source "${3}"
main help
EOF

  # Run arty - should not fail
  output=$(bash "$TEST_ENV_DIR/run_test.sh" "$ARTY_HOME" "$TEST_ENV_DIR" "$ARTY_SH" 2>&1)
  exit_code=$?

  assert_equals "0" "$exit_code" "Should exit successfully without envs section"

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
  check: "echo APP_ENV=$APP_ENV SHARED_VAR=$SHARED_VAR"
EOF

  # Create wrapper script with development environment
  cat >"$TEST_ENV_DIR/run_test.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
export ARTY_CONFIG_FILE="${2}/arty.yml"
export ARTY_ENV="development"
cd "${2}"
source "${3}"
main check
EOF

  # Run with development environment
  output=$(bash "$TEST_ENV_DIR/run_test.sh" "$ARTY_HOME" "$TEST_ENV_DIR" "$ARTY_SH" 2>/dev/null)

  # Check that development overrides default
  assert_contains "$output" "APP_ENV=development" "APP_ENV should be development"
  assert_contains "$output" "SHARED_VAR=from_development" "SHARED_VAR should be overridden by development"

  teardown
}

# Test: Pre-existing environment variables are not overridden by default
test_preserve_existing_env_vars() {
  setup

  # Create test arty.yml
  cat >arty.yml <<'EOF'
name: "test-project"
version: "1.0.0"

envs:
  default:
    APP_ENV: "default"
    LOG_LEVEL: "info"

scripts:
  check: "echo APP_ENV=$APP_ENV LOG_LEVEL=$LOG_LEVEL"
EOF

  # Create wrapper script with pre-existing APP_ENV
  cat >"$TEST_ENV_DIR/run_test.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
export ARTY_CONFIG_FILE="${2}/arty.yml"
export APP_ENV="pre_existing"
cd "${2}"
source "${3}"
main check
EOF

  # Run arty with pre-existing APP_ENV
  output=$(bash "$TEST_ENV_DIR/run_test.sh" "$ARTY_HOME" "$TEST_ENV_DIR" "$ARTY_SH" 2>/dev/null)

  # Check that pre-existing variable was preserved (for default env only)
  assert_contains "$output" "APP_ENV=pre_existing" "Pre-existing APP_ENV should be preserved in default env"
  assert_contains "$output" "LOG_LEVEL=info" "LOG_LEVEL should still be set"

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

  # Create wrapper script to run help command
  cat >"$TEST_ENV_DIR/run_test.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
export ARTY_CONFIG_FILE="${2}/arty.yml"
cd "${2}"
source "${3}"
main help
EOF

  # Run arty - should handle gracefully
  output=$(bash "$TEST_ENV_DIR/run_test.sh" "$ARTY_HOME" "$TEST_ENV_DIR" "$ARTY_SH" 2>&1)

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

  # Create wrapper script to run print_var
  cat >"$TEST_ENV_DIR/run_test.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
export ARTY_CONFIG_FILE="${2}/arty.yml"
cd "${2}"
source "${3}"
main print_var
EOF

  # Run script and capture output
  output=$(bash "$TEST_ENV_DIR/run_test.sh" "$ARTY_HOME" "$TEST_ENV_DIR" "$ARTY_SH" 2>/dev/null)

  assert_equals "hello_world" "$output" "Script should have access to env vars"

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

  # Create wrapper script to run help command
  cat >"$TEST_ENV_DIR/run_test.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
export ARTY_CONFIG_FILE="${2}/arty.yml"
cd "${2}"
source "${3}"
main help
EOF

  # Run arty and capture stderr
  output=$(bash "$TEST_ENV_DIR/run_test.sh" "$ARTY_HOME" "$TEST_ENV_DIR" "$ARTY_SH" 2>&1)

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
  check_staging: "echo ENV_NAME=$ENV_NAME STAGING_ONLY=${STAGING_ONLY:-}"
  check_production: "echo ENV_NAME=$ENV_NAME PROD_ONLY=${PROD_ONLY:-}"
EOF

  # Test staging environment
  cat >"$TEST_ENV_DIR/run_staging.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
export ARTY_CONFIG_FILE="${2}/arty.yml"
export ARTY_ENV="staging"
cd "${2}"
source "${3}"
main check_staging
EOF

  output=$(bash "$TEST_ENV_DIR/run_staging.sh" "$ARTY_HOME" "$TEST_ENV_DIR" "$ARTY_SH" 2>/dev/null)
  assert_contains "$output" "ENV_NAME=staging" "Should load staging environment"
  assert_contains "$output" "STAGING_ONLY=yes" "Should have staging-only variable"

  # Test production environment
  cat >"$TEST_ENV_DIR/run_production.sh" <<'EOF'
#!/usr/bin/env bash
export ARTY_HOME="${1}"
export ARTY_CONFIG_FILE="${2}/arty.yml"
export ARTY_ENV="production"
cd "${2}"
source "${3}"
main check_production
EOF

  output=$(bash "$TEST_ENV_DIR/run_production.sh" "$ARTY_HOME" "$TEST_ENV_DIR" "$ARTY_SH" 2>/dev/null)
  assert_contains "$output" "ENV_NAME=production" "Should load production environment"
  assert_contains "$output" "PROD_ONLY=yes" "Should have production-only variable"

  teardown
}

# Run all tests
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
