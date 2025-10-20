# arty.sh

A bash library repository management system built with arty.sh.

## Features

- 📦 Install bash libraries from Git repositories
- 🔗 Dependency management via `arty.yml`
- 🪝 Setup hooks for library initialization
- 🌐 Curl-installable for easy distribution
- 📋 Package-like configuration with `arty.yml`

## System Requirements

- Bash 4.0 or higher
- Git
- `yq` - YAML processor (https://github.com/mikefarah/yq)

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

## Installation

### Quick Install (curl)

```bash
curl -sSL https://raw.githubusercontent.com/{{organization_name}}/arty.sh/main/arty.sh | sudo tee /usr/local/bin/arty > /dev/null
sudo chmod +x /usr/local/bin/arty
```

### Manual Install

```bash
git clone https://github.com/{{organization_name}}/arty.sh.git
cd arty.sh
sudo cp arty.sh /usr/local/bin/arty
sudo chmod +x /usr/local/bin/arty
```

## Usage

### Initialize a New Project

```bash
arty init my-project
```

This creates an `arty.yml` configuration file.

### Install a Library

```bash
arty install https://github.com/{{organization_name}}/{{demo_project_name}}.git
```

### Install with Custom Name

```bash
arty install https://github.com/user/lib.git my-custom-name
```

### Install Dependencies

```bash
# Installs all libraries listed in arty.yml references
arty deps
```

### List Installed Libraries

```bash
arty list
```

### Remove a Library

```bash
arty remove library-name
```

### Use a Library in Your Script

```bash
#!/usr/bin/env bash

# Source the library
source <(arty source utils)

# Use functions from the library
utils_function
```

### Execute a Library's Main Script

If a library defines a `main` field in its `arty.yml`, it will be linked to `.arty/bin/<library-name>` and can be executed directly:

```bash
# Execute library's main script
arty exec leaf --help
arty exec mylib process data.txt

# The library receives all arguments after the library name
arty exec tool --verbose --output result.log input.txt
```

## arty.yml Configuration

```yaml
name: "my-awesome-library"
version: "1.0.0"
description: "An awesome bash library"
author: "Your Name"
license: "MIT"

# Dependencies
references:
  - https://github.com/user/bash-utils.git
  - https://github.com/user/logger.git

# Entry point (will be linked to .arty/bin/my-awesome-library)
main: "lib.sh"

# Scripts
scripts:
  test: "bash test.sh"
  build: "bash build.sh"
```

### Main Script Linking

When a library defines a `main` field:
- The script is automatically linked to `.arty/bin/<library-name>` after installation
- The script is made executable
- It can be executed via `arty exec <library-name> [args]`
- All arguments after the library name are passed to the main script

## Setup Hook

Libraries can include a `setup.sh` file that runs automatically during installation:

```bash
#!/usr/bin/env bash
# setup.sh

echo "Setting up library..."
# Perform initialization tasks
```

## Environment Variables

- `ARTY_HOME`: Home directory for arty (default: `~/.arty`)
- `ARTY_CONFIG`: Config file name (default: `arty.yml`)

## Examples

### Creating a Reusable Library

```bash
# Initialize project
arty init my-utils

# Edit arty.yml to add metadata
nano arty.yml

# Create your library file
cat > my-utils.sh << 'EOF'
#!/usr/bin/env bash

# Process command line arguments
case "${1:-}" in
    greet)
        echo "Hello from my-utils!"
        ;;
    process)
        shift
        echo "Processing: $@"
        ;;
    --help|-h)
        echo "Usage: my-utils <command> [args]"
        echo "Commands:"
        echo "  greet           - Say hello"
        echo "  process [args]  - Process arguments"
        ;;
    *)
        echo "Unknown command. Use --help for usage."
        exit 1
        ;;
esac
EOF

# Update arty.yml to set main field
cat > arty.yml << 'EOF'
name: "my-utils"
version: "1.0.0"
description: "My utility library"
main: "my-utils.sh"

scripts:
  test: "bash test.sh"
EOF

# Commit and push to Git
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/user/my-utils.git
git push -u origin main
```

### Using the Library in Another Project

```bash
# Create a new project
mkdir my-project && cd my-project
arty init my-project

# Add the library as a dependency
cat > arty.yml << 'EOF'
name: "my-project"
version: "0.1.0"

references:
  - https://github.com/user/my-utils.git

scripts:
  start: "arty exec my-utils greet"
EOF

# Install dependencies
arty deps

# Execute the library's main script
arty exec my-utils greet
arty exec my-utils process file1.txt file2.txt

# Or run via script
arty start
```

### Library with Multiple Dependencies

```bash
# arty.yml for a complex project
cat > arty.yml << 'EOF'
name: "web-scraper"
version: "2.0.0"
description: "A web scraping tool"
author: "Your Name"

references:
  - https://github.com/user/http-client.git
  - https://github.com/user/html-parser.git
  - https://github.com/user/logger.git

main: "scraper.sh"

scripts:
  test: "bash tests/run-tests.sh"
  scrape: "arty exec web-scraper --url"
  lint: "shellcheck *.sh"
EOF

# Install all dependencies and link main scripts
arty deps

# Now you can execute any dependency's main script
arty exec http-client GET https://example.com
arty exec html-parser parse data.html
arty exec web-scraper --url https://example.com --output result.json
```

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

Generated by hammer.sh on 2025-10-19
