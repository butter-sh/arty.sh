# arty.sh - YQ Integration Update

## Summary of Changes

The `arty.sh` script has been updated to use `yq` (a lightweight and portable command-line YAML processor) instead of custom bash-based YAML parsing. This provides more robust and reliable YAML parsing capabilities.

## System Requirements

### Required Dependencies
- **Bash 4.0 or higher**
- **Git** - For cloning repositories
- **yq** - YAML processor (https://github.com/mikefarah/yq)

### Installing yq

**On macOS:**
```bash
brew install yq
```

**On Linux:**
```bash
# Download latest release
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

**On Debian/Ubuntu:**
```bash
sudo apt-get install yq
```

## Key Features

### 1. YQ Dependency Check
The script now checks if `yq` is installed on startup and provides helpful error messages with installation instructions if it's missing.

### 2. New Helper Functions

#### `get_yaml_field(file, field)`
Retrieves a single field value from a YAML file.
```bash
name=$(get_yaml_field "arty.yml" "name")
version=$(get_yaml_field "arty.yml" "version")
```

#### `get_yaml_array(file, field)`
Retrieves array items from a YAML file.
```bash
while IFS= read -r ref; do
    echo "$ref"
done < <(get_yaml_array "arty.yml" "references")
```

#### `get_yaml_script(file, script_name)`
Retrieves a specific script command from the scripts section.
```bash
cmd=$(get_yaml_script "arty.yml" "test")
```

#### `list_yaml_scripts(file)`
Lists all available script names from the scripts section.
```bash
while IFS= read -r script_name; do
    echo "$script_name"
done < <(list_yaml_scripts "arty.yml")
```

### 3. Updated Functions

All functions that previously used custom bash YAML parsing now use `yq`:

- **`install_references()`** - Uses `get_yaml_array()` to read references
- **`install_deps()`** - Uses `get_yaml_array()` for dependencies and `get_yaml_field()` for main script
- **`list_libs()`** - Uses `get_yaml_field()` to read version information
- **`exec_script()`** - Uses `get_yaml_script()` and `list_yaml_scripts()` for script execution

## Testing

Two test scripts are provided:

### test-yq-functions.sh
Tests the individual yq helper functions:
```bash
bash test-yq-functions.sh
```

This verifies:
- Reading single fields
- Reading array values
- Reading script commands
- Listing available scripts

### test-deps.sh
End-to-end test of the deps command:
```bash
bash test-deps.sh
```

This verifies:
- Directory structure creation (`.arty/`, `.arty/bin/`, `.arty/libs/`)
- Git repository cloning
- Main script linking
- Script execution via `arty <script-name>`

## Example Usage

### arty.yml
```yaml
name: "my-awesome-library"
version: "1.0.0"
description: "An awesome bash library"
author: "Your Name"
license: "MIT"

references:
  - https://github.com/butter-sh/leaf.sh.git
  - https://github.com/user/utils.git

main: "lib.sh"

scripts:
  test: "bash test.sh"
  build: "bash build.sh"
  lint: "shellcheck *.sh"
```

### Commands
```bash
# Initialize project
arty init my-project

# Install dependencies from arty.yml
arty deps

# Run scripts defined in arty.yml
arty test
arty build
arty lint

# List installed libraries
arty list
```

## Benefits of Using yq

1. **Robust Parsing** - Handles complex YAML structures reliably
2. **Standards Compliant** - Follows YAML 1.2 specification
3. **Better Error Handling** - Clear error messages for malformed YAML
4. **Wide Adoption** - Well-maintained and widely used in the community
5. **Feature Rich** - Supports advanced YAML operations if needed in the future

## Migration Notes

If you have an existing `arty.sh` installation:

1. Install `yq` using one of the methods above
2. Update `arty.sh` to the new version
3. No changes to `arty.yml` files are required - the format remains the same

## Documentation

The README.md has been updated to include:
- System Requirements section
- yq installation instructions for multiple platforms
- Links to the official yq repository

## Backward Compatibility

The `arty.yml` format remains unchanged. All existing `arty.yml` files will work with the new yq-based implementation without modification.

## Error Handling

The script now provides better error messages:
- Missing `yq` installation with installation instructions
- Clear feedback when scripts are not found
- List of available scripts when an invalid script name is provided

---

**Version:** 1.0.0 with yq integration
**Last Updated:** $(date)
