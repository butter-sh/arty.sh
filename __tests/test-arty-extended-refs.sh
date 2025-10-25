#!/bin/bash
# Test suite for arty extended reference format

# Source test helpers
if ! declare -f assert_contains >/dev/null; then
  echo "Error: Test helpers not loaded. This test must be run via judge.sh"
  exit 1
fi

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

# Test: parse simple string reference
test_parse_simple_reference() {
  setup

  cat >"$TEST_ENV_DIR/arty.yml" <<'EOF'
name: "test"
version: "1.0.0"
references:
  - https://github.com/user/repo.git
EOF

  # Create test script to call parse_reference
  cat >"$TEST_ENV_DIR/test_parse.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
result=$(parse_reference "$2" 0)
echo "$result"
EOF

  output=$(bash "$TEST_ENV_DIR/test_parse.sh" "$ARTY_SH" "$TEST_ENV_DIR/arty.yml")

  assert_contains "$output" "https://github.com/user/repo.git" "Should extract URL from simple reference"
  teardown
}

# Test: parse extended reference with all fields
test_parse_extended_reference() {
  setup

  cat >"$TEST_ENV_DIR/arty.yml" <<'EOF'
name: "test"
version: "1.0.0"
references:
  - url: git@github.com:user/repo.git
    into: custom/path
    ref: v1.0.0
    env: production
EOF

  # Create test script
  cat >"$TEST_ENV_DIR/test_parse.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
result=$(parse_reference "$2" 0)
echo "$result"
EOF

  output=$(bash "$TEST_ENV_DIR/test_parse.sh" "$ARTY_SH" "$TEST_ENV_DIR/arty.yml")

  assert_contains "$output" "git@github.com:user/repo.git" "Should extract URL"
  assert_contains "$output" "custom/path" "Should extract into path"
  assert_contains "$output" "v1.0.0" "Should extract ref"
  assert_contains "$output" "production" "Should extract env"
  teardown
}

# Test: dry-run mode flag
test_dry_run_mode() {
  setup

  cat >"$TEST_ENV_DIR/arty.yml" <<'EOF'
name: "test"
version: "1.0.0"
references: []
EOF

  output=$(bash "$ARTY_SH" deps --dry-run 2>&1)

  assert_contains "$output" "DRY RUN" "Should indicate dry run mode"
  assert_contains "$output" "No references" "Should show no references message"
  teardown
}

# Test: environment filtering
test_environment_filter() {
  setup

  cat >"$TEST_ENV_DIR/arty.yml" <<'EOF'
name: "test"
version: "1.0.0"
references:
  - url: https://github.com/user/repo1.git
  - url: https://github.com/user/repo2.git
    env: production
EOF

  # Test with default environment (should skip production-only ref)
  output=$(ARTY_ENV=default bash "$ARTY_SH" deps --dry-run 2>&1)

  assert_contains "$output" "repo1.git" "Should install default reference"
  assert_contains "$output" "Skipping reference" "Should skip production reference"

  teardown
}

# Test: environment filter with list of environments
test_environment_filter_list() {
  setup

  cat >"$TEST_ENV_DIR/arty.yml" <<'EOF'
name: "test"
version: "1.0.0"
references:
  - url: https://github.com/user/repo1.git
  - url: https://github.com/user/repo2.git
    env: [dev, ci]
  - url: https://github.com/user/repo3.git
    env: production
EOF

  # Test with dev environment (should install repo1 and repo2, skip repo3)
  output=$(ARTY_ENV=dev bash "$ARTY_SH" deps --dry-run 2>&1)

  assert_contains "$output" "repo1.git" "Should install default reference"
  assert_contains "$output" "repo2.git" "Should install dev reference"
  assert_contains "$output" "Skipping reference" "Should skip production reference"

  teardown
}

# Test: environment filter list with ci environment
test_environment_filter_list_ci() {
  setup

  cat >"$TEST_ENV_DIR/arty.yml" <<'EOF'
name: "test"
version: "1.0.0"
references:
  - url: https://github.com/user/repo1.git
  - url: https://github.com/user/repo2.git
    env: [dev, ci]
EOF

  # Test with ci environment (should install both)
  output=$(ARTY_ENV=ci bash "$ARTY_SH" deps --dry-run 2>&1)

  assert_contains "$output" "repo1.git" "Should install default reference"
  assert_contains "$output" "repo2.git" "Should install ci reference"

  teardown
}

# Test: check_env_match function
test_check_env_match() {
  setup

  # Create test script
  cat >"$TEST_ENV_DIR/test_env_match.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"

# Test single env match
if check_env_match "dev" "dev"; then
  echo "PASS: dev matches dev"
else
  echo "FAIL: dev should match dev"
fi

# Test single env no match
if check_env_match "prod" "dev"; then
  echo "FAIL: prod should not match dev"
else
  echo "PASS: prod does not match dev"
fi

# Test list match first item
if check_env_match "dev" "dev,ci"; then
  echo "PASS: dev matches dev,ci"
else
  echo "FAIL: dev should match dev,ci"
fi

# Test list match second item
if check_env_match "ci" "dev,ci"; then
  echo "PASS: ci matches dev,ci"
else
  echo "FAIL: ci should match dev,ci"
fi

# Test list no match
if check_env_match "prod" "dev,ci"; then
  echo "FAIL: prod should not match dev,ci"
else
  echo "PASS: prod does not match dev,ci"
fi

# Test empty filter (should always match)
if check_env_match "anything" ""; then
  echo "PASS: anything matches empty filter"
else
  echo "FAIL: anything should match empty filter"
fi
EOF

  output=$(bash "$TEST_ENV_DIR/test_env_match.sh" "$ARTY_SH")

  assert_contains "$output" "PASS: dev matches dev" "Should match single env"
  assert_contains "$output" "PASS: prod does not match dev" "Should not match different env"
  assert_contains "$output" "PASS: dev matches dev,ci" "Should match first item in list"
  assert_contains "$output" "PASS: ci matches dev,ci" "Should match second item in list"
  assert_contains "$output" "PASS: prod does not match dev,ci" "Should not match unlisted env"
  assert_contains "$output" "PASS: anything matches empty filter" "Empty filter should match all"

  teardown
}

# Test: get_git_info function
test_get_git_info() {
  setup

  # Create a git repository
  mkdir -p "$TEST_ENV_DIR/test_repo"
  cd "$TEST_ENV_DIR/test_repo"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test User"
  echo "test" > file.txt
  git add file.txt
  git commit -q -m "Initial commit"

  # Test git info extraction
  cat >"$TEST_ENV_DIR/test_git_info.sh" <<'EOF'
#!/usr/bin/env bash
source "${1}"
result=$(get_git_info "$2")
echo "$result"
EOF

  output=$(bash "$TEST_ENV_DIR/test_git_info.sh" "$ARTY_SH" "$TEST_ENV_DIR/test_repo")

  # Output format: commit_hash|refs|is_dirty
  # Should have commit hash
  assert_not_equals "$output" "|||0" "Should extract git information"

  teardown
}

# Test: list command shows tree structure
test_list_tree_structure() {
  setup

  cat >"$TEST_ENV_DIR/arty.yml" <<'EOF'
name: "test-project"
version: "1.0.0"
references: []
EOF

  output=$(bash "$ARTY_SH" list 2>&1)

  assert_contains "$output" "test-project" "Should show project name"
  assert_contains "$output" "1.0.0" "Should show project version"
  assert_contains "$output" "No libraries installed" "Should indicate no libraries"
  teardown
}

# Test: nested into directives are relative to their defining arty.yml
test_nested_into_relative_paths() {
  setup

  # Create root arty.yml with into directive
  cat >arty.yml <<'EOF'
name: "root"
version: "1.0.0"
references:
  - url: https://github.com/user/parent.git
    into: custom/parent
EOF

  # Create parent directory and arty.yml with nested into directive
  mkdir -p custom/parent
  cat >custom/parent/arty.yml <<'EOF'
name: "parent"
version: "2.0.0"
references:
  - url: https://github.com/user/child.git
    into: nested/child
EOF

  # Initialize git in parent
  (cd custom/parent && git init -q && git config user.email "t@t.com" && git config user.name "T" && touch f && git add . && git commit -q -m "init")

  # Test that child's location is relative to parent's arty.yml
  output=$(bash "$ARTY_SH" deps --dry-run 2>&1)

  # Child should be at custom/parent/nested/child (relative to parent's arty.yml)
  assert_contains "$output" "custom/parent/nested/child" "Nested into should be relative to parent arty.yml"

  teardown
}

# Run all tests
run_tests() {
  log_section "Extended Reference Format Tests"

  test_parse_simple_reference
  test_parse_extended_reference
  test_dry_run_mode
  test_environment_filter
  test_environment_filter_list
  test_environment_filter_list_ci
  test_check_env_match
  test_get_git_info
  test_list_tree_structure
  test_nested_into_relative_paths
}

export -f run_tests
