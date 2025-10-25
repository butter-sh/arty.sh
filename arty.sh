#!/bin/bash

# arty.sh - A bash library repository management system
# Version: 1.0.0

set -euo pipefail

ARTY_CONFIG_FILE="${ARTY_CONFIG_FILE:-arty.yml}"
ARTY_ENV="${ARTY_ENV:-default}"
ARTY_DRY_RUN="${ARTY_DRY_RUN:-0}"

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
        # Only export if not already set (for default env only)
        if [[ "$current_env" == "default" ]] && [[ -n "${!key:-}" ]]; then
          log_info "  Skipping $key (already set)"
          continue
        fi
        export "$key=$value"
        log_info "  Set $key (from default)"
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
  local arty_home="${ARTY_HOME:-$PWD/.arty}"
  local libs_dir="${ARTY_LIBS_DIR:-$arty_home/libs}"
  local bin_dir="${ARTY_BIN_DIR:-$arty_home/bin}"

  if [[ ! -d "$arty_home" ]]; then
    mkdir -p "$libs_dir"
    mkdir -p "$bin_dir"
    log_success "Initialized arty at $arty_home"
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

# Parse reference - can be a string URL or an object with url, into, ref, env
# Returns: url|into|ref|env (pipe-delimited)
# env can be a single value or comma-separated list
parse_reference() {
  local config_file="$1"
  local ref_index="$2"

  # Check if reference is a string or object
  local ref_type=$(yq eval ".references[$ref_index] | type" "$config_file" 2>/dev/null)

  if [[ "$ref_type" == "!!str" ]]; then
    # Simple string format: just the URL
    local url=$(yq eval ".references[$ref_index]" "$config_file" 2>/dev/null)
    echo "$url||||"
  else
    # Object format with url, into, ref, env fields
    local url=$(yq eval ".references[$ref_index].url" "$config_file" 2>/dev/null)
    local into=$(yq eval ".references[$ref_index].into" "$config_file" 2>/dev/null)
    local ref=$(yq eval ".references[$ref_index].ref" "$config_file" 2>/dev/null)

    # Check if env is an array or string
    local env_type=$(yq eval ".references[$ref_index].env | type" "$config_file" 2>/dev/null)
    local env=""

    if [[ "$env_type" == "!!seq" ]]; then
      # Array format - convert to comma-separated string
      env=$(yq eval ".references[$ref_index].env | join(\",\")" "$config_file" 2>/dev/null)
    else
      # Single value or null
      env=$(yq eval ".references[$ref_index].env" "$config_file" 2>/dev/null)
    fi

    # Replace "null" with empty string
    [[ "$url" == "null" ]] && url=""
    [[ "$into" == "null" ]] && into=""
    [[ "$ref" == "null" ]] && ref=""
    [[ "$env" == "null" ]] && env=""

    echo "$url|$into|$ref|$env"
  fi
}

# Check if current environment matches the filter
# env_filter can be a single env or comma-separated list
check_env_match() {
  local current_env="$1"
  local env_filter="$2"

  # No filter means match all
  [[ -z "$env_filter" ]] && return 0

  # Convert comma-separated list to array
  IFS=',' read -ra env_list <<< "$env_filter"

  # Check if current env is in the list
  for env in "${env_list[@]}"; do
    # Trim whitespace
    env=$(echo "$env" | xargs)
    if [[ "$env" == "$current_env" ]]; then
      return 0
    fi
  done

  return 1
}

# Get git information for a repository
get_git_info() {
  local repo_dir="$1"

  if [[ ! -d "$repo_dir/.git" ]]; then
    echo "|||0"
    return
  fi

  # Get short commit hash
  local commit_hash=$(cd "$repo_dir" && git rev-parse --short HEAD 2>/dev/null || echo "")

  # Get all refs pointing to current commit (tags, branches)
  local refs=$(cd "$repo_dir" && git describe --all --exact-match 2>/dev/null || git symbolic-ref --short HEAD 2>/dev/null || echo "")

  # Clean up refs (remove heads/ and tags/ prefixes)
  refs=$(echo "$refs" | sed 's#^heads/##' | sed 's#^tags/##')

  # Check if dirty (has uncommitted changes)
  local is_dirty=0
  if [[ -n "$(cd "$repo_dir" && git status --porcelain 2>/dev/null)" ]]; then
    is_dirty=1
  fi

  echo "$commit_hash|$refs|$is_dirty"
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
  local libs_dir="${ARTY_LIBS_DIR:-${ARTY_HOME:-$PWD/.arty}/libs}"
  [[ -d "$libs_dir/$lib_name" ]]
}

# Install a library from git repository
install_lib() {
  local repo_url="$1"
  local lib_name="${2:-$(get_lib_name "$repo_url")}"
  local git_ref="${3:-main}"
  local custom_into="${4:-}"
  local config_file="${5:-$ARTY_CONFIG_FILE}"

  # Determine installation directory
  local lib_dir
  if [[ -n "$custom_into" ]]; then
    # Custom directory relative to config file directory
    local config_dir=$(dirname "$(realpath "${config_file}")")
    lib_dir="$config_dir/$custom_into"
  else
    # Use global .arty/libs for libraries without custom 'into'
    lib_dir="$ARTY_LIBS_DIR/$lib_name"
  fi

  # Normalize the library identifier for circular dependency detection
  local lib_id=$(normalize_lib_id "$repo_url")

  # Check for circular dependency
  if is_installing "$lib_id"; then
    log_warn "Circular dependency detected: $lib_name (already being installed)"
    log_info "Skipping to prevent infinite loop"
    return 0
  fi

  # Check if already installed (optimization)
  if [[ -d "$lib_dir" ]]; then
    log_info "Library '$lib_name' already installed at $lib_dir"

    if [[ "$ARTY_DRY_RUN" == "1" ]]; then
      log_info "[DRY RUN] Would check for updates..."
      # Mark as installing before processing nested deps to prevent infinite loops
      mark_installing "$lib_id"
      # Still process nested dependencies even in dry-run
      if [[ -f "$lib_dir/arty.yml" ]]; then
        log_info "Found arty.yml, checking for references..."
        install_references "$lib_dir/arty.yml"
      fi
      unmark_installing "$lib_id"
      return 0
    fi

    # Try to update
    (cd "$lib_dir" && git fetch -q && git checkout -q "$git_ref" && git pull -q) || {
      log_warn "Failed to update library (continuing with existing version)"
    }

    # Mark as installing before processing nested deps to prevent infinite loops
    mark_installing "$lib_id"
    # Process nested dependencies even for already-installed libraries
    if [[ -f "$lib_dir/arty.yml" ]]; then
      log_info "Found arty.yml, checking for references..."
      install_references "$lib_dir/arty.yml"
    fi
    unmark_installing "$lib_id"

    return 0
  fi

  # Mark as currently installing
  mark_installing "$lib_id"

  if [[ "$ARTY_DRY_RUN" != "1" ]]; then
    init_arty
  fi

  log_info "Installing library: $lib_name"
  log_info "Repository: $repo_url"
  log_info "Git ref: $git_ref"
  log_info "Location: $lib_dir"

  if [[ "$ARTY_DRY_RUN" == "1" ]]; then
    log_info "[DRY RUN] Would clone repository and checkout $git_ref"
    unmark_installing "$lib_id"
    return 0
  fi

  # Clone the repository
  git clone "$repo_url" "$lib_dir" || {
    log_error "Failed to clone repository"
    unmark_installing "$lib_id"
    return 1
  }

  # Checkout the specified ref
  (cd "$lib_dir" && git checkout -q "$git_ref") || {
    log_warn "Failed to checkout ref '$git_ref', using default branch"
  }

  # Run setup hook if exists
  if [[ -f "$lib_dir/setup.sh" ]]; then
    log_info "Running setup hook..."
    (cd "$lib_dir" && bash setup.sh) || {
      log_warn "Setup hook failed, continuing anyway..."
    }
  fi

  # Process arty.yml if it exists
  if [[ -f "$lib_dir/arty.yml" ]]; then
    # Link main script to .arty/bin (only for standard installations, not custom 'into')
    if [[ -z "$custom_into" ]]; then
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
    fi

    # Install nested dependencies (always, regardless of 'into')
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

  # Initialize arty directory structure first (unless dry run)
  if [[ "$ARTY_DRY_RUN" != "1" ]]; then
    init_arty
  fi

  # Count references
  local ref_count=$(yq eval '.references | length' "$config_file" 2>/dev/null)
  if [[ "$ref_count" == "null" ]] || [[ "$ref_count" == "0" ]]; then
    log_info "No references to install"
    return 0
  fi

  # Process each reference by index
  for ((i = 0; i < ref_count; i++)); do
    # Parse the reference
    local ref_data=$(parse_reference "$config_file" "$i")
    IFS='|' read -r url into git_ref env_filter <<<"$ref_data"

    # Skip empty URLs
    if [[ -z "$url" ]] || [[ "$url" == "null" ]]; then
      continue
    fi

    # Check environment filter using the new check_env_match function
    if [[ -n "$env_filter" ]] && ! check_env_match "$ARTY_ENV" "$env_filter"; then
      log_info "Skipping reference (env filter: [$env_filter], current: $ARTY_ENV): $url"
      continue
    fi

    # Use default ref if not specified
    [[ -z "$git_ref" ]] && git_ref="main"

    # Get library name
    local lib_name=$(get_lib_name "$url")

    log_info "Installing reference: $url"
    [[ -n "$into" ]] && log_info "Custom location: $into"
    [[ -n "$env_filter" ]] && log_info "Environment filter: [$env_filter]"

    install_lib "$url" "$lib_name" "$git_ref" "$into" "$config_file" || log_warn "Failed to install reference: $url"
  done
}

# Build a reference tree from arty.yml showing all dependencies
build_reference_tree() {
  local config_file="${1:-$ARTY_CONFIG_FILE}"
  local indent="${2:-}"
  local is_last="${3:-1}"
  local visited_file="${4:-/tmp/arty_visited_$$}"

  if [[ ! -f "$config_file" ]]; then
    return 0
  fi

  # Prevent infinite loops by tracking visited configs
  local config_path=$(realpath "$config_file" 2>/dev/null || echo "$config_file")
  if grep -qx "$config_path" "$visited_file" 2>/dev/null; then
    return 0
  fi
  echo "$config_path" >>"$visited_file"

  # Count references
  local ref_count=$(yq eval '.references | length' "$config_file" 2>/dev/null)
  if [[ "$ref_count" == "null" ]] || [[ "$ref_count" == "0" ]]; then
    return 0
  fi

  # Process each reference
  for ((i = 0; i < ref_count; i++)); do
    local ref_data=$(parse_reference "$config_file" "$i")
    IFS='|' read -r url into git_ref env_filter <<<"$ref_data"

    # Skip if no URL or env filter doesn't match
    if [[ -z "$url" ]] || [[ "$url" == "null" ]]; then
      continue
    fi
    if [[ -n "$env_filter" ]] && ! check_env_match "$ARTY_ENV" "$env_filter"; then
      continue
    fi

    local lib_name=$(get_lib_name "$url")
    local is_last_ref=0
    [[ $((i + 1)) -eq $ref_count ]] && is_last_ref=1

    # Determine installation directory
    local lib_dir
    if [[ -n "$into" ]]; then
      local config_dir=$(dirname "$(realpath "${config_file}")")
      lib_dir="$config_dir/$into"
    else
      lib_dir="$ARTY_LIBS_DIR/$lib_name"
    fi

    # Get version and git info
    local version=""
    local location="$lib_dir"

    if [[ -f "$lib_dir/arty.yml" ]]; then
      version=$(get_yaml_field "$lib_dir/arty.yml" "version")
      [[ "$version" == "null" ]] || [[ -z "$version" ]] && version=""
    fi

    # Get git information
    local git_info=$(get_git_info "$lib_dir")
    IFS='|' read -r commit_hash git_refs is_dirty <<<"$git_info"

    # Determine display version
    local display_version="${version:-$commit_hash}"
    [[ -z "$display_version" ]] && display_version="unknown"

    # Tree characters
    local tree_char="├──"
    local tree_continue="│   "
    if [[ "$is_last_ref" == "1" ]]; then
      tree_char="└──"
      tree_continue="    "
    fi

    # Print the reference line
    printf "%s${tree_char} ${BOLD}${GREEN}%s${NC}" "$indent" "$lib_name"
    printf " ${CYAN}%s${NC}" "$display_version"

    # Add git refs if available
    if [[ -n "$git_refs" ]]; then
      printf " ${BLUE}(%s)${NC}" "$git_refs"
    fi

    # Add dirty indicator
    if [[ "$is_dirty" == "1" ]]; then
      printf " ${YELLOW}✗${NC}"
    fi

    # Add location info
    if [[ -n "$into" ]]; then
      printf " ${MAGENTA}→ %s${NC}" "$into"
    fi

    echo

    # Recursively show nested dependencies
    if [[ -f "$lib_dir/arty.yml" ]]; then
      build_reference_tree "$lib_dir/arty.yml" "${indent}${tree_continue}" "$is_last_ref" "$visited_file"
    fi
  done
}

# List installed libraries with tree visualization
list_libs() {
  init_arty

  if [[ ! -f "$ARTY_CONFIG_FILE" ]]; then
    # Fallback to simple list if no arty.yml
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
    return 0
  fi

  # Get project info
  local project_name=$(get_yaml_field "$ARTY_CONFIG_FILE" "name")
  local project_version=$(get_yaml_field "$ARTY_CONFIG_FILE" "version")

  # Clean up name/version
  [[ "$project_name" == "null" ]] && project_name="$(basename "$PWD")"
  [[ "$project_version" == "null" ]] && project_version=""

  # Check if there are any references
  local ref_count=$(yq eval '.references | length' "$ARTY_CONFIG_FILE" 2>/dev/null)
  if [[ "$ref_count" == "null" ]] || [[ "$ref_count" == "0" ]]; then
    # No references defined, check for installed libraries
    local libs_dir="${ARTY_LIBS_DIR:-${ARTY_HOME:-$PWD/.arty}/libs}"
    if [[ ! -d "$libs_dir" ]] || [[ -z "$(ls -A "$libs_dir" 2>/dev/null)" ]]; then
      # Show header but indicate no libraries
      echo
      printf "${BOLD}${GREEN}%s${NC}" "$project_name"
      if [[ -n "$project_version" ]]; then
        printf " ${CYAN}%s${NC}" "$project_version"
      fi
      echo
      echo
      log_info "No libraries installed"
      echo
      return 0
    fi
  fi

  # Print header
  echo
  printf "${BOLD}${GREEN}%s${NC}" "$project_name"
  if [[ -n "$project_version" ]]; then
    printf " ${CYAN}%s${NC}" "$project_version"
  fi
  echo
  echo

  # Create temporary file for tracking visited configs
  local visited_file="/tmp/arty_visited_$$"
  : >"$visited_file"

  # Build and display tree
  build_reference_tree "$ARTY_CONFIG_FILE" "" 1 "$visited_file"

  # Cleanup
  rm -f "$visited_file"

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
  local libs_dir="${ARTY_LIBS_DIR:-${ARTY_HOME:-$PWD/.arty}/libs}"
  local lib_path="$libs_dir/$lib_name/$lib_file"

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
  local bin_dir="${ARTY_BIN_DIR:-${ARTY_HOME:-$PWD/.arty}/bin}"
  local bin_path="$bin_dir/$lib_name_stripped"

  if [[ ! -f "$bin_path" ]]; then
    log_error "Library executable not found: $lib_name_stripped"
    log_info "Make sure the library is installed with 'arty deps' or 'arty install'"
    log_info "Available executables:"
    if [[ -d "$bin_dir" ]]; then
      for exec_file in $bin_dir/*; do
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
    arty <command> [arguments] [--dry-run]

COMMANDS:
    install <repo-url> [name]  Install a library from git repository
    deps [--dry-run]           Install all dependencies from arty.yml
    list                       List installed libraries with dependency tree
    remove <name>              Remove an installed library
    init [name]                Initialize a new arty.yml project
    source <name> [file]       Source a library (for use in scripts)
    exec <lib-name> [args]     Execute a library's main script with arguments
    <script-name>              Execute a script defined in arty.yml
    help                       Show this help message

FLAGS:
    --dry-run                  Simulate installation without making changes

EXAMPLES:
    # Install a library
    arty install https://github.com/user/bash-utils.git

    # Install with custom name
    arty install https://github.com/user/lib.git my-lib

    # Install dependencies from arty.yml
    arty deps

    # Dry run dependencies installation
    arty deps --dry-run

    # List installed libraries with tree view
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

REFERENCE FORMATS:
    References in arty.yml can be specified in two formats:

    1. Simple URL format:
       references:
         - https://github.com/user/repo.git

    2. Extended object format:
       references:
         - url: git@github.com:user/repo.git
           into: custom/path       # Custom installation directory (relative to arty.yml)
           ref: v1.0.0            # Git ref (branch, tag, or commit hash; default: main)
           env: production        # Only install in this environment

    3. Extended format with multiple environments:
       references:
         - url: git@github.com:user/dev-tools.git
           env: [dev, ci]         # Install in dev OR ci environment

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

  # Configuration
  PROJECT_DIR="$PWD/.arty"
  ARTY_HOME="${ARTY_HOME:-$PROJECT_DIR}"
  ARTY_LIBS_DIR="${ARTY_LIBS_DIR:-$ARTY_HOME/libs}"
  ARTY_BIN_DIR="${ARTY_BIN_DIR:-$ARTY_HOME/bin}"

  if [[ $# -eq 0 ]]; then
    show_usage
    exit 0
  fi

  local command="$1"
  shift

  # Check for --dry-run flag
  local dry_run_flag=0
  for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
      dry_run_flag=1
      break
    fi
  done

  # Remove --dry-run from arguments
  local args=()
  for arg in "$@"; do
    if [[ "$arg" != "--dry-run" ]]; then
      args+=("$arg")
    fi
  done

  # Set dry run mode
  if [[ "$dry_run_flag" == "1" ]]; then
    export ARTY_DRY_RUN=1
    log_info "${YELLOW}[DRY RUN MODE]${NC} Simulating actions, no changes will be made"
    echo
  fi

  case "$command" in
  install)
  if [[ ${#args[@]} -eq 0 ]]; then
    install_references
    local install_result=$?
    else
    install_lib "${args[@]}"
    local install_result=$?
  fi
  # Show tree after installation if successful and arty.yml exists and has references
  if [[ $install_result -eq 0 ]] && [[ -f "$ARTY_CONFIG_FILE" ]]; then
    local ref_count=$(yq eval '.references | length' "$ARTY_CONFIG_FILE" 2>/dev/null)
    if [[ "$ref_count" != "null" ]] && [[ "$ref_count" != "0" ]]; then
      echo
      log_success "Installation complete!"
      list_libs
    fi
  fi
  ;;
  deps)
  install_references
  local install_result=$?
  # Show tree after installation if successful and arty.yml exists and has references
  if [[ $install_result -eq 0 ]] && [[ -f "$ARTY_CONFIG_FILE" ]]; then
    local ref_count=$(yq eval '.references | length' "$ARTY_CONFIG_FILE" 2>/dev/null)
    if [[ "$ref_count" != "null" ]] && [[ "$ref_count" != "0" ]]; then
      echo
      log_success "Dependencies installed!"
      list_libs
    fi
  fi
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
