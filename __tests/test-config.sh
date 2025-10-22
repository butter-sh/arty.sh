#!/bin/bash
# Test configuration for arty.sh test suite
# This file is sourced by test files to set common configuration
export TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ARTY_SH="${TEST_ROOT}/../arty.sh"
# Test directory structure
export ARTY_SH_ROOT="$PWD"

# Test behavior flags
export ARTY_TEST_MODE=1
export ARTY_SKIP_YQ_CHECK=0 # Set to 1 to skip yq availability check in tests

# Color output in tests (set to 0 to disable)
export ARTY_TEST_COLORS=1
