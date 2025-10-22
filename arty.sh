#!/bin/bash

# arty.sh - A bash library repository management system
# Version: 1.0.0

set -euo pipefail

# Configuration
PROJECT_DIR="$PWD/.arty"
ARTY_HOME="${ARTY_HOME:-$PROJECT_DIR}"
ARTY_LIBS_DIR="$ARTY_HOME/libs"
ARTY_BIN_DIR="$ARTY_HOME/bin"
ARTY_CONFIG_FILE="${ARTY_CONFIG_FILE:-arty.yml}"
ARTY_ENV="${ARTY_ENV:-default}"

# Colors for output - only use colors if output is to a terminal or if FORCE_COLOR is set
export FORCE_COLOR=${FORCE_COLOR:-"1"}
if [[ "$FORCE_COLOR" = "0" ]]; then
  export RED=''
  export GREEN=''
  export YELLOW=''
  export BLUE=''
  export CYAN=''
  export MAGENTA=''
  export BOLD=''
  export NC=''
else
  export RED='\033[0;31m'
  export GREEN='\033[0;32m'
  export YELLOW='\033[1;33m'
  export BLUE='\033[0;34m'
  export CYAN='\033[0;36m'
  export MAGENTA='\033[0;35m'
  export BOLD='\033[1m'
  export NC='\033[0m'
fi

# Global array to track installation stack (prevent circular dependencies)
declare -g -A ARTY_INSTALL_STACK

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Load environment variables from arty.yml
load_env_vars() {
  local config_file="${1:-$ARTY_CONFIG_FILE}"

  if [[ ! -f "$config_file" ]]; then
    return 0 # No config file, nothing to load
  fi

  # Check if YAML is valid
  if ! yq eval '.' "$config_file" >/dev/null 2>&1; then
    log_warn "Invalid YAML in config file, skipping env vars"
    return 0
  fi

  # Check if envs section exists
  local has_envs=$(yq eval '.envs' "$config_file" 2>/dev/null)
  if [[ "$has_envs" == "null" ]] || [[ -z "$has_envs" ]]; then
    return 0 # No envs section
  fi

  local current_env="$ARTY_ENV"
  log_info "Loading environment variables from '$current_env' environment"

  # First load default variables if they exist
  if yq eval '.envs.default' "$config_file" 2>/dev/null | grep -q -v '^null$'; then
    while IFS='=' read -r key value; do
      if [[ -n "$key" ]] && [[ "$key" != "null" ]] && [[ -n "$value" ]]; then
        # Only export if not already set
        if [[ -z "${!key:-}" ]]; then
          export "$key=$value"
          log_info "  Set $key (from default)"
        fi
      fi
    done < <(yq eval '.envs.default | to_entries | .[] | .key + "=" + .value' "$config_file" 2>/dev/null)
  fi

  # Then load environment-specific variables (which can override defaults)
  if [[ "$current_env" != "default" ]]; then
    if yq eval ".envs.$current_env" "$config_file" 2>/dev/null | grep -q -v '^null$'; then
      while IFS='=' read -r key value; do
        if [[ -n "$key" ]] && [[ "$key" != "null" ]] && [[ -n "$value" ]]; then
          export "$key=$value"
          log_info "  Set $key (from $current_env)"
        fi
      done < <(yq eval ".envs.$current_env | to_entries | .[] | .key + \"=\" + .value" "$config_file" 2>/dev/null)
    fi
  fi
}

# Check if yq is installed
check_yq() {
  if ! command -v yq &>/dev/null; then
    log_error "yq is not installed. Please install yq to use arty."
    log_info "Visit https://github.com/mikefarah/yq for installation instructions"
    log_info "Quick install: brew install yq (macOS) or see README.md"
    exit 1
  fi
}

# Initialize arty environment
init_arty() {
  if [[ ! -d "$ARTY_HOME" ]]; then
    mkdir -p "$ARTY_LIBS_DIR"
    mkdir -p "$ARTY_BIN_DIR"
    log_success "Initialized arty at $ARTY_HOME"
  fi
}

# Get a field from YAML using yq
get_yaml_field() {
  local file="$1"
  local field="$2"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  # Check if file has valid YAML - yq will exit with error on invalid YAML
  if ! yq eval '.' "$file" >/dev/null 2>&1; then
    return 1
  fi

  yq eval ".$field" "$file" 2>/dev/null || echo ""
}

# Get array items from YAML using yq
get_yaml_array() {
  local file="$1"
  local field="$2"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  # Check if file has valid YAML - yq will exit with error on invalid YAML
  if ! yq eval '.' "$file" >/dev/null 2>&1; then
    return 1
  fi

  yq eval ".${field}[]" "$file" 2>/dev/null
}

# Get script command from YAML
get_yaml_script() {
  local file="$1"
  local script_name="$2"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  yq eval ".scripts.${script_name}" "$file" 2>/dev/null || echo "null"
}

# List all script names from YAML
list_yaml_scripts() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  yq eval '.scripts | keys | .[]' "$file" 2>/dev/null
}

# Get library name from repository URL
get_lib_name() {
  local repo_url="$1"
  basename "$repo_url" .git
}

# Normalize library identifier for tracking
normalize_lib_id() {
  local repo_url="$1"
  # Convert to lowercase and remove .git suffix for consistent tracking
  echo "${repo_url,,}" | sed 's/\.git$//'
}

# Check if library is in installation stack
is_installing() {
  local lib_id="$1"
  [[ -n "${ARTY_INSTALL_STACK[$lib_id]:-}" ]]
}

# Add library to installation stack
mark_installing() {
  local lib_id="$1"
  ARTY_INSTALL_STACK[$lib_id]=1
}

# Remove library from installation stack
unmark_installing() {
  local lib_id="$1"
  unset ARTY_INSTALL_STACK[$lib_id]
}

# Check if library is already installed
is_installed() {
  local lib_name="$1"
  [[ -d "$ARTY_LIBS_DIR/$lib_name" ]]
}

# Install a library from git repository
install_lib() {
  local repo_url="$1"
  local lib_name="${2:-$(get_lib_name "$repo_url")}"
  local lib_dir="$ARTY_LIBS_DIR/$lib_name"

  # Normalize the library identifier for circular dependency detection
  local lib_id=$(normalize_lib_id "$repo_url")

  # Check for circular dependency
  if is_installing "$lib_id"; then
    log_warn "Circular dependency detected: $lib_name (already being installed)"
    log_info "Skipping to prevent infinite loop"
    return 0
  fi

  # Check if already installed (optimization)
  if is_installed "$lib_name"; then
    log_info "Library '$lib_name' already installed, checking for updates..."
    # Still try to update, but don't reinstall dependencies
    (cd "$lib_dir" && git pull -q) || {
      log_warn "Failed to update library (continuing with existing version)"
    }
    return 0
  fi

  # Mark as currently installing
  mark_installing "$lib_id"

  init_arty

  log_info "Installing library: $lib_name"
  log_info "Repository: $repo_url"

  # Clone the repository
  git clone "$repo_url" "$lib_dir" || {
    log_error "Failed to clone repository"
    unmark_installing "$lib_id"
    return 1
  }

  # Run setup hook if exists
  if [[ -f "$lib_dir/setup.sh" ]]; then
    log_info "Running setup hook..."
    (cd "$lib_dir" && bash setup.sh) || {
      log_warn "Setup hook failed, continuing anyway..."
    }
  fi

  # Link main script to .arty/bin if arty.yml has a main field
  if [[ -f "$lib_dir/arty.yml" ]]; then
    local main_script=$(get_yaml_field "$lib_dir/arty.yml" "main")
    if [[ -n "$main_script" ]] && [[ "$main_script" != "null" ]]; then
      local main_file="$lib_dir/$main_script"
      if [[ -f "$main_file" ]]; then
        local local_bin_dir="$ARTY_BIN_DIR"
        local lib_name_stripped="$(basename $main_file .sh)"
        local bin_link="$local_bin_dir/$lib_name_stripped"

        log_info "Linking main script: $main_script -> $bin_link"
        ln -sf "$main_file" "$bin_link"
        chmod +x "$main_file"
        log_success "Main script linked to $bin_link"
      fi
    fi

    # Install references from the library's arty.yml
    log_info "Found arty.yml, checking for references..."
    install_references "$lib_dir/arty.yml"
  fi

  # Unmark as installing (we're done with this library)
  unmark_installing "$lib_id"

  log_success "Library '$lib_name' installed successfully"
  log_info "Location: $lib_dir"
}

# Install all references from arty.yml
install_references() {
  local config_file="${1:-$ARTY_CONFIG_FILE}"

  if [[ ! -f "$config_file" ]]; then
    log_error "Config file not found: $config_file"
    return 1
  fi

  # Check if YAML is valid by trying to read it
  if ! yq eval '.' "$config_file" >/dev/null 2>&1; then
    log_error "Invalid YAML in config file: $config_file"
    return 1
  fi

  # Initialize arty directory structure first
  init_arty

  # Get all references using yq
  while IFS= read -r ref; do
    if [[ -n "$ref" ]] && [[ "$ref" != "null" ]]; then
      log_info "Installing reference: $ref"
      install_lib "$ref" || log_warn "Failed to install reference: $ref"
    fi
  done < <(get_yaml_array "$config_file" "references")
}

# List installed libraries
list_libs() {
  init_arty

  if [[ ! -d "$ARTY_LIBS_DIR" ]] || [[ -z "$(ls -A "$ARTY_LIBS_DIR" 2>/dev/null)" ]]; then
    log_info "No libraries installed"
    return 0
  fi

  log_info "Installed libraries:"
  echo

  for lib_dir in "$ARTY_LIBS_DIR"/*; do
    if [[ -d "$lib_dir" ]]; then
      local lib_name=$(basename "$lib_dir")
      local version=""

      # Try to get version from arty.yml using yq
      if [[ -f "$lib_dir/arty.yml" ]]; then
        version=$(get_yaml_field "$lib_dir/arty.yml" "version")
        if [[ "$version" == "null" ]] || [[ -z "$version" ]]; then
          version=""
        fi
      fi

      printf "  ${GREEN}%-20s${NC} %s\n" "$lib_name" "${version:-(unknown version)}"
    fi
  done
  echo
}

# Remove a library
remove_lib() {
  local lib_name="$1"
  local lib_dir="$ARTY_LIBS_DIR/$lib_name"

  if [[ ! -d "$lib_dir" ]]; then
    log_error "Library not found: $lib_name"
    return 1
  fi

  log_info "Removing library: $lib_name"
  rm -rf "$lib_dir"
  log_success "Library removed"
}

# Initialize a new arty.yml project
init_project() {
  local project_name="${1:-$(basename "$PWD")}"

  if [[ -f "$ARTY_CONFIG_FILE" ]]; then
    log_error "arty.yml already exists in current directory"
    return 1
  fi

  log_info "Initializing new arty project: $project_name"

  # Create local .arty folder structure
  local local_arty_dir=".arty"
  local local_bin_dir="$local_arty_dir/bin"
  local local_libs_dir="$local_arty_dir/libs"

  log_info "Creating project structure"
  mkdir -p "$local_bin_dir" "$local_libs_dir"

  cat >"$ARTY_CONFIG_FILE" <<EOF
name: "$project_name"
version: "0.1.0"
description: "A bash library project"
author: ""
license: "MIT"

# Dependencies from other arty.sh repositories
references:
  # - https://github.com/user/some-bash-lib.git
  # - https://github.com/user/another-lib.git

# Entry point script
main: "index.sh"

# Scripts that can be executed
scripts:
  test: "bash test.sh"
  build: "bash build.sh"
EOF

  log_success "Created $ARTY_CONFIG_FILE"
  log_success "Created .arty/ folder structure"
}

# Source/load a library
source_lib() {
  local lib_name="$1"
  local lib_file="${2:-index.sh}"
  local lib_path="$ARTY_LIBS_DIR/$lib_name/$lib_file"

  if [[ ! -f "$lib_path" ]]; then
    log_error "Library file not found: $lib_path"
    return 1
  fi

  source "$lib_path"
}

# Execute a library's main script
exec_lib() {
  local lib_name="$1"
  shift # Remove lib_name from arguments, rest are passed to the script

  local lib_name_stripped="$(basename $lib_name .sh)"
  local bin_path="$ARTY_BIN_DIR/$lib_name_stripped"

  if [[ ! -f "$bin_path" ]]; then
    log_error "Library executable not found: $lib_name_stripped"
    log_info "Make sure the library is installed with 'arty deps' or 'arty install'"
    log_info "Available executables:"
    if [[ -d "$ARTY_BIN_DIR" ]]; then
      for exec_file in $ARTY_BIN_DIR/*; do
        if [[ -f "$exec_file" ]]; then
          echo "  -- $(basename "$exec_file")"
        fi
      done
    else
      echo "  (none found - run 'arty deps' first)"
    fi
    return 1
  fi

  if [[ ! -x "$bin_path" ]]; then
    log_error "Library executable is not executable: $bin_path"
    return 1
  fi

  # Execute the library's main script with all passed arguments
  "$bin_path" "$@"
}

# Show usage
show_usage() {
  cat <<'EOF'
arty.sh - A bash library repository management system

USAGE:
    arty <command> [arguments]

COMMANDS:
    install <repo-url> [name]  Install a library from git repository
    deps                       Install all dependencies from arty.yml
    list                       List installed libraries
    remove <name>              Remove an installed library
    init [name]                Initialize a new arty.yml project
    source <name> [file]       Source a library (for use in scripts)
    exec <lib-name> [args]     Execute a library's main script with arguments
    <script-name>              Execute a script defined in arty.yml
    help                       Show this help message

EXAMPLES:
    # Install a library
    arty install https://github.com/user/bash-utils.git

    # Install with custom name
    arty install https://github.com/user/lib.git my-lib

    # Install dependencies from arty.yml
    arty deps

    # List installed libraries
    arty list

    # Initialize new project
    arty init my-project

    # Execute a script from arty.yml
    arty test
    arty build

    # Execute a library's main script
    arty exec leaf --help
    arty exec mylib process file.txt

    # Source library in a script
    source <(arty source utils)

    # Use different environment
    ARTY_ENV=production arty test

PROJECT STRUCTURE:
    When running 'arty init' or 'arty deps', the following structure is created:

    project/
    ├── .arty/
    │   ├── bin/           # Linked executables (from 'main' field)
    │   │   ├── index      # Project's main script
    │   │   ├── leaf       # Dependency's main script
    │   │   └── mylib      # Another dependency's main script
    │   └── libs/          # Dependencies (from 'references' field)
    │       ├── dep1/
    │       └── dep2/
    └── arty.yml           # Project configuration

ENVIRONMENT:
    ARTY_HOME       Home directory for arty (default: ~/.arty)
    ARTY_CONFIG     Config file name (default: arty.yml)
    ARTY_ENV        Environment to load from arty.yml envs section (default: default)

INSTALLATION:
    # Install arty.sh globally
    curl -sSL https://raw.githubusercontent.com/{{organization_name}}/arty.sh/main/arty.sh | sudo tee /usr/local/bin/arty > /dev/null
    sudo chmod +x /usr/local/bin/arty

EOF
}

# Execute a script from arty.yml
exec_script() {
  local script_name="$1"
  local config_file="${ARTY_CONFIG_FILE}"

  if [[ ! -f "$config_file" ]]; then
    log_error "Config file not found: $config_file"
    log_info "Run this command in a directory with arty.yml"
    return 1
  fi

  # Get script command using yq
  local cmd=$(get_yaml_script "$config_file" "$script_name")

  if [[ -z "$cmd" ]] || [[ "$cmd" == "null" ]]; then
    log_error "Script not found in arty.yml: $script_name"
    log_info "Available scripts:"
    while IFS= read -r name; do
      if [[ -n "$name" ]]; then
        echo "  - $name"
      fi
    done < <(list_yaml_scripts "$config_file")
    return 1
  fi

  log_info "Executing script: $script_name"
  eval "$cmd"
  return $?
}

# Main function
main() {
  # Check for yq availability first
  check_yq

  # Load environment variables before any other operation
  load_env_vars

  if [[ $# -eq 0 ]]; then
    show_usage
    exit 0
  fi

  local command="$1"
  shift

  case "$command" in
  install)
    if [[ $# -eq 0 ]]; then
      install_references
    else
      install_lib "$@"
    fi
    ;;
  deps)
    install_references
    ;;
  list | ls)
    list_libs
    ;;
  remove | rm)
    if [[ $# -eq 0 ]]; then
      log_error "Library name required"
      exit 1
    fi
    remove_lib "$1"
    ;;
  init)
    init_project "$@"
    ;;
  exec)
    if [[ $# -eq 0 ]]; then
      log_error "Library name required"
      log_info "Usage: arty exec <library-name> [arguments]"
      exit 1
    fi
    exec_lib "$@"
    ;;
  source)
    if [[ $# -eq 0 ]]; then
      log_error "Library name required"
      exit 1
    fi
    source_lib "$@"
    ;;
  help | --help | -h)
    show_usage
    ;;
  *)
    # Try to execute as a script from arty.yml
    exec_script "$command" "$@"
    ;;
  esac
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
