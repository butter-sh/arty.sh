<div align="center">

# 📦 arty.sh

**Bash Library Repository Management System**

[![Organization](https://img.shields.io/badge/org-butter--sh-4ade80?style=for-the-badge&logo=github&logoColor=white)](https://github.com/butter-sh)
[![License](https://img.shields.io/badge/license-MIT-86efac?style=for-the-badge)](LICENSE)
[![Build Status](https://img.shields.io/github/actions/workflow/status/butter-sh/arty.sh/test.yml?branch=main&style=flat-square&logo=github&color=22c55e)](https://github.com/butter-sh/arty.sh/actions)
[![Version](https://img.shields.io/github/v/tag/butter-sh/arty.sh?style=flat-square&label=version&color=4ade80)](https://github.com/butter-sh/arty.sh/releases)
[![butter.sh](https://img.shields.io/badge/butter.sh-arty-22c55e?style=flat-square&logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cGF0aCBkPSJNMjEgMTZWOGEyIDIgMCAwIDAtMS0xLjczbC03LTRhMiAyIDAgMCAwLTIgMGwtNyA0QTIgMiAwIDAgMCAzIDh2OGEyIDIgMCAwIDAgMSAxLjczbDcgNGEyIDIgMCAwIDAgMiAwbDctNEEyIDIgMCAwIDAgMjEgMTZ6IiBzdHJva2U9IiM0YWRlODAiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIi8+PHBvbHlsaW5lIHBvaW50cz0iMy4yNyA2Ljk2IDEyIDEyLjAxIDIwLjczIDYuOTYiIHN0cm9rZT0iIzRhZGU4MCIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiLz48bGluZSB4MT0iMTIiIHkxPSIyMi4wOCIgeDI9IjEyIiB5Mj0iMTIiIHN0cm9rZT0iIzRhZGU4MCIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiLz48L3N2Zz4=)](https://butter-sh.github.io/arty.sh)

*Install bash libraries from Git repositories with complete dependency management*

[Documentation](https://butter-sh.github.io/arty.sh) • [GitHub](https://github.com/butter-sh/arty.sh) • [butter.sh](https://github.com/butter-sh)

</div>

---

## Features

- 📦 **Install bash libraries** from Git repositories
- 🔗 **Dependency management** via `arty.yml`
- 🪝 **Setup hooks** for library initialization
- 🔗 **Binary linking** for executable scripts
- 🌐 **Curl-installable** for easy distribution
- 📋 **Package-like configuration** with YAML

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
curl -sSL https://raw.githubusercontent.com/butter-sh/arty.sh/main/arty.sh | sudo tee /usr/local/bin/arty > /dev/null
sudo chmod +x /usr/local/bin/arty
```

### Using hammer.sh

```bash
hammer arty my-project
cd my-project
```

### Manual Install

```bash
git clone https://github.com/butter-sh/arty.sh.git
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
arty install https://github.com/butter-sh/kompose.sh.git
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

## Related Projects

Part of the butter.sh ecosystem:

- **[hammer.sh](https://github.com/butter-sh/hammer.sh)** - Generate projects from templates
- **[judge.sh](https://github.com/butter-sh/judge.sh)** - Testing framework with assertions
- **[leaf.sh](https://github.com/butter-sh/leaf.sh)** - Documentation generator
- **[whip.sh](https://github.com/butter-sh/whip.sh)** - Release cycle management
- **[myst.sh](https://github.com/butter-sh/myst.sh)** - Templating engine

## License

MIT License - see [LICENSE](LICENSE) file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Author

Created by [valknar](https://github.com/valknarogg)

---

<div align="center">

Part of the [butter.sh](https://github.com/butter-sh) ecosystem

**Unlimited. Independent. Fresh.**

</div>
