#!/usr/bin/env bash

# arty.sh - A bash library repository management system
# Version: 1.0.0

set -euo pipefail

# Configuration
ARTY_HOME="${ARTY_HOME:-$HOME/.arty}"
ARTY_LIBS_DIR="$ARTY_HOME/libs"
ARTY_CONFIG_FILE="${ARTY_CONFIG_FILE:-arty.yml}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Initialize arty environment
init_arty() {
    if [[ ! -d "$ARTY_HOME" ]]; then
        mkdir -p "$ARTY_LIBS_DIR"
        log_success "Initialized arty at $ARTY_HOME"
    fi
}

# Parse YAML (simple implementation for arty.yml)
parse_yaml() {
    local file="$1"
    local prefix="${2:-}"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local s='[[:space:]]*'
    local w='[a-zA-Z0-9_-]*'
    
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\2=\"\3\"|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\2=\"\3\"|p" "$file" |
    sed -e "s/^/${prefix}/" \
        -e 's/_/-/g'
}

# Read arty.yml configuration
read_config() {
    local config_file="${1:-$ARTY_CONFIG_FILE}"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi
    
    # Parse basic fields
    eval "$(parse_yaml "$config_file")"
}

# Get library name from repository URL
get_lib_name() {
    local repo_url="$1"
    basename "$repo_url" .git
}

# Install a library from git repository
install_lib() {
    local repo_url="$1"
    local lib_name="${2:-$(get_lib_name "$repo_url")}"
    local lib_dir="$ARTY_LIBS_DIR/$lib_name"
    
    init_arty
    
    log_info "Installing library: $lib_name"
    log_info "Repository: $repo_url"
    
    # Clone or update repository
    if [[ -d "$lib_dir" ]]; then
        log_info "Library already exists, updating..."
        (cd "$lib_dir" && git pull) || {
            log_error "Failed to update library"
            return 1
        }
    else
        git clone "$repo_url" "$lib_dir" || {
            log_error "Failed to clone repository"
            return 1
        }
    fi
    
    # Run setup hook if exists
    if [[ -f "$lib_dir/setup.sh" ]]; then
        log_info "Running setup hook..."
        (cd "$lib_dir" && bash setup.sh) || {
            log_warn "Setup hook failed, continuing anyway..."
        }
    fi
    
    # Check for arty.yml and install references
    if [[ -f "$lib_dir/arty.yml" ]]; then
        log_info "Found arty.yml, checking for references..."
        install_references "$lib_dir/arty.yml"
    fi
    
    log_success "Library '$lib_name' installed successfully"
    log_info "Location: $lib_dir"
}

# Install all references from arty.yml
install_references() {
    local config_file="$1"
    local in_references=false
    local line_num=0
    
    while IFS= read -r line; do
        line_num=$((line_num+1))
        
        # Check if we're entering references section
        if [[ "$line" =~ ^references:[[:space:]]*$ ]]; then
            in_references=true
            continue
        fi
        
        # Check if we're leaving references section
        if [[ "$in_references" == true ]] && [[ "$line" =~ ^[a-zA-Z] ]]; then
            in_references=false
        fi
        
        # Parse reference entries
        if [[ "$in_references" == true ]] && [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
            local ref="${BASH_REMATCH[1]}"
            log_info "Installing reference: $ref"
            install_lib "$ref" || log_warn "Failed to install reference: $ref"
        fi
    done < "$config_file"
}

# Install dependencies from local arty.yml
install_deps() {
    local config_file="${1:-$ARTY_CONFIG_FILE}"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi
    
    # Create local .arty folder structure
    local local_arty_dir=".arty"
    local local_bin_dir="$local_arty_dir/bin"
    local local_libs_dir="$local_arty_dir/libs"
    
    log_info "Creating local arty structure"
    mkdir -p "$local_bin_dir" "$local_libs_dir"
    
    log_info "Installing dependencies from $config_file"
    
    # Install references into local .arty/libs/<DEPENDENCY_NAME>
    local in_references=false
    local line_num=0
    
    while IFS= read -r line; do
        line_num=$((line_num+1))
        
        # Check if we're entering references section
        if [[ "$line" =~ ^references:[[:space:]]*$ ]]; then
            in_references=true
            continue
        fi
        
        # Check if we're leaving references section
        if [[ "$in_references" == true ]] && [[ "$line" =~ ^[a-zA-Z] ]]; then
            in_references=false
        fi
        
        # Parse reference entries
        if [[ "$in_references" == true ]] && [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
            local ref="${BASH_REMATCH[1]}"
            local dep_name=$(get_lib_name "$ref")
            local dep_dir="$local_libs_dir/$dep_name"
            
            log_info "Installing dependency: $dep_name"
            
            # Clone or update dependency
            if [[ -d "$dep_dir" ]]; then
                log_info "Dependency already exists, updating..."
                (cd "$dep_dir" && git pull) || {
                    log_error "Failed to update dependency: $dep_name"
                    continue
                }
            else
                git clone "$ref" "$dep_dir" || {
                    log_error "Failed to clone dependency: $dep_name"
                    continue
                }
            fi
            
            # Run setup hook if exists
            if [[ -f "$dep_dir/setup.sh" ]]; then
                log_info "Running setup hook for $dep_name..."
                (cd "$dep_dir" && bash setup.sh) || {
                    log_warn "Setup hook failed for $dep_name, continuing anyway..."
                }
            fi
            
            log_success "Dependency '$dep_name' installed successfully"
        fi
    done < "$config_file"
    
    # Link main script to .arty/bin if defined
    local main_script=$(grep "^main:" "$config_file" | cut -d':' -f2 | tr -d ' "')
    if [[ -n "$main_script" ]] && [[ -f "$main_script" ]]; then
        local main_name=$(basename "$main_script" .sh)
        local bin_link="$local_bin_dir/$main_name"
        
        log_info "Linking main script: $main_script -> $bin_link"
        ln -sf "../../$main_script" "$bin_link"
        chmod +x "$main_script"
        log_success "Main script linked and made executable"
    elif [[ -n "$main_script" ]]; then
        log_warn "Main script defined but not found: $main_script"
    fi
    
    log_success "All dependencies installed"
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
            
            # Try to get version from arty.yml
            if [[ -f "$lib_dir/arty.yml" ]]; then
                version=$(grep "^version:" "$lib_dir/arty.yml" | cut -d':' -f2 | tr -d ' "')
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
    
    cat > "$ARTY_CONFIG_FILE" << EOF
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

# Show usage
show_usage() {
    cat << 'EOF'
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

    # Source library in a script
    source <(arty source utils)

PROJECT STRUCTURE:
    When running 'arty init' or 'arty deps', the following structure is created:
    
    project/
    ├── .arty/
    │   ├── bin/           # Linked executables (from 'main' field)
    │   └── libs/          # Dependencies (from 'references' field)
    │       ├── dep1/
    │       └── dep2/
    └── arty.yml           # Project configuration

ENVIRONMENT:
    ARTY_HOME       Home directory for arty (default: ~/.arty)
    ARTY_CONFIG     Config file name (default: arty.yml)

INSTALLATION:
    # Install arty.sh globally
    curl -sSL https://raw.githubusercontent.com/butter-sh/arty.sh/main/arty.sh | sudo tee /usr/local/bin/arty > /dev/null
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
    
    # Parse scripts section
    local in_scripts=false
    local found_script=false
    
    while IFS= read -r line; do
        # Check if we're entering scripts section
        if [[ "$line" =~ ^scripts:[[:space:]]*$ ]]; then
            in_scripts=true
            continue
        fi
        
        # Check if we're leaving scripts section
        if [[ "$in_scripts" == true ]] && [[ "$line" =~ ^[a-zA-Z] ]]; then
            in_scripts=false
        fi
        
        # Parse script entries
        if [[ "$in_scripts" == true ]] && [[ "$line" =~ ^[[:space:]]+([a-zA-Z0-9_-]+):[[:space:]]*(.+)$ ]]; then
            local name="${BASH_REMATCH[1]}"
            local cmd="${BASH_REMATCH[2]}"
            # Remove quotes if present
            cmd=$(echo "$cmd" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
            
            if [[ "$name" == "$script_name" ]]; then
                found_script=true
                log_info "Executing script: $script_name"
                eval "$cmd"
                return $?
            fi
        fi
    done < "$config_file"
    
    if [[ "$found_script" == false ]]; then
        log_error "Script not found in arty.yml: $script_name"
        log_info "Available scripts:"
        grep -A 100 "^scripts:" "$config_file" | grep "^  [a-zA-Z]" | sed 's/^  /  - /' | cut -d':' -f1
        return 1
    fi
}

# Main function
main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        install)
            if [[ $# -eq 0 ]]; then
                log_error "Repository URL required"
                exit 1
            fi
            install_lib "$@"
            ;;
        deps)
            install_deps "$@"
            ;;
        list|ls)
            list_libs
            ;;
        remove|rm)
            if [[ $# -eq 0 ]]; then
                log_error "Library name required"
                exit 1
            fi
            remove_lib "$1"
            ;;
        init)
            init_project "$@"
            ;;
        source)
            if [[ $# -eq 0 ]]; then
                log_error "Library name required"
                exit 1
            fi
            source_lib "$@"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            # Try to execute as a script from arty.yml
            if [[ -f "$ARTY_CONFIG_FILE" ]]; then
                exec_script "$command" "$@"
            else
                log_error "Unknown command: $command"
                show_usage
                exit 1
            fi
            ;;
    esac
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
