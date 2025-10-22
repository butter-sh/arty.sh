<div align="center">

<img src="./icon.svg" width="100" height="100" alt="arty.sh">

# arty.sh

**Bash Dependency Manager**

[![Organization](https://img.shields.io/badge/org-butter--sh-4ade80?style=for-the-badge&logo=github&logoColor=white)](https://github.com/butter-sh)
[![License](https://img.shields.io/badge/license-MIT-86efac?style=for-the-badge)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-22c55e?style=for-the-badge)](https://github.com/butter-sh/arty.sh/releases)
[![butter.sh](https://img.shields.io/badge/butter.sh-arty-4ade80?style=for-the-badge)](https://butter-sh.github.io)

*Install and manage bash libraries from Git repositories with complete dependency resolution*

[Documentation](https://butter-sh.github.io/arty.sh) • [GitHub](https://github.com/butter-sh/arty.sh) • [butter.sh](https://github.com/butter-sh)

</div>

---

## Overview

arty.sh is a professional dependency manager for bash libraries, bringing modern package management concepts to shell scripting. Install libraries from Git repositories, manage complex dependency graphs, and execute library scripts with a simple, intuitive CLI.

### Key Features

- **Git Repository Integration** — Install any bash library directly from Git
- **Dependency Resolution** — Automatic dependency graph management with circular detection
- **Binary Linking** — Executable scripts automatically linked to `.arty/bin/`
- **YAML Configuration** — Clean, readable project configuration with `arty.yml`
- **Setup Hooks** — Automatic library initialization during installation
- **Script Execution** — Run project scripts with `arty <script-name>`

---

## Installation

### Quick Install (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/butter-sh/arty.sh/main/arty.sh \
  | sudo tee /usr/local/bin/arty > /dev/null
sudo chmod +x /usr/local/bin/arty
```

### Manual Installation

```bash
git clone https://github.com/butter-sh/arty.sh.git
cd arty.sh
sudo cp arty.sh /usr/local/bin/arty
sudo chmod +x /usr/local/bin/arty
```

### Using hammer.sh

```bash
hammer arty my-project
cd my-project
```

---

## System Requirements

- **Bash** 4.0 or higher
- **Git** for repository management
- **yq** — YAML processor ([installation guide](https://github.com/mikefarah/yq))

### Installing yq

**macOS:**
```bash
brew install yq
```

**Linux:**
```bash
sudo wget -qO /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

**Debian/Ubuntu:**
```bash
sudo apt-get install yq
```

---

## Usage

### Initialize a Project

```bash
arty init my-project
```

Creates an `arty.yml` configuration file with project metadata.

### Install Libraries

```bash
# Install from Git repository
arty install https://github.com/butter-sh/myst.sh.git

# Install with custom name
arty install https://github.com/user/lib.git my-lib

# Install all dependencies from arty.yml
arty deps
```

### Manage Libraries

```bash
# List installed libraries
arty list

# Remove a library
arty remove library-name

# Update a library
arty update library-name
```

### Execute Library Scripts

If a library defines a `main` field in `arty.yml`, it's linked to `.arty/bin/` and can be executed:

```bash
# Execute library's main script
arty exec leaf --help
arty exec myst template.myst -d data.json

# All arguments after the library name are passed through
arty exec tool --verbose --output result.log input.txt
```

### Source Libraries in Scripts

```bash
#!/usr/bin/env bash

# Source a library
source <(arty source utils)

# Use library functions
utils_function
```

---

## Configuration

### arty.yml Structure

```yaml
name: "my-project"
version: "1.0.0"
description: "A professional bash application"
author: "Your Name <email@example.com>"
license: "MIT"

# Dependencies (installed with 'arty deps')
references:
  - https://github.com/butter-sh/myst.sh.git
  - https://github.com/butter-sh/judge.sh.git

# Entry point (linked to .arty/bin/my-project)
main: "my-project.sh"

# Custom scripts (run with 'arty <script-name>')
scripts:
  test: "bash __tests/run.sh"
  lint: "shellcheck *.sh"
  build: "bash build.sh"
  deploy: "bash deploy.sh"
```

### Main Script Linking

When a library defines a `main` field:
- Script is automatically linked to `.arty/bin/<library-name>`
- Script is made executable
- Can be run via `arty exec <library-name> [args]`
- All arguments are passed to the main script

---

## Examples

### Creating a Reusable Library

```bash
# 1. Initialize project
arty init my-utils
cd my-utils

# 2. Create main script
cat > my-utils.sh << 'EOF'
#!/usr/bin/env bash

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

# 3. Configure arty.yml
cat > arty.yml << 'EOF'
name: "my-utils"
version: "1.0.0"
description: "My utility library"
main: "my-utils.sh"

scripts:
  test: "bash __tests/run.sh"
EOF

# 4. Publish to Git
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/user/my-utils.git
git push -u origin main
```

### Using the Library in Another Project

```bash
# 1. Create new project
mkdir my-project && cd my-project
arty init my-project

# 2. Add library as dependency
cat > arty.yml << 'EOF'
name: "my-project"
version: "0.1.0"

references:
  - https://github.com/user/my-utils.git

scripts:
  greet: "arty exec my-utils greet"
EOF

# 3. Install dependencies
arty deps

# 4. Execute library
arty exec my-utils greet
arty exec my-utils process file1.txt file2.txt

# Or use custom script
arty greet
```

### Complex Dependency Management

```bash
cat > arty.yml << 'EOF'
name: "web-scraper"
version: "2.0.0"
description: "A web scraping tool"

references:
  - https://github.com/user/http-client.git
  - https://github.com/user/html-parser.git
  - https://github.com/user/logger.git
  - https://github.com/butter-sh/myst.sh.git
  - https://github.com/butter-sh/judge.sh.git

main: "scraper.sh"

scripts:
  test: "arty exec judge run"
  scrape: "arty exec web-scraper --url"
  lint: "shellcheck *.sh"
  format: "arty exec clean format *.sh"
EOF

# Install all dependencies with dependency resolution
arty deps

# Execute any library's main script
arty exec http-client GET https://example.com
arty exec html-parser parse data.html
arty exec myst template.myst -d data.json
```

---

## Setup Hooks

Libraries can include a `setup.sh` file that runs automatically during installation:

```bash
#!/usr/bin/env bash
# setup.sh

echo "Setting up library..."

# Create directories
mkdir -p data/
mkdir -p cache/

# Generate config files
cat > config/default.yml << 'EOF'
enabled: true
timeout: 30
EOF

# Download resources
curl -sSL https://example.com/resource -o data/resource.json

echo "Setup complete!"
```

The setup script runs in the library's installation directory (`.arty/libs/<library-name>/`).

---

## Environment Variables

- `ARTY_HOME` — Home directory for arty (default: `~/.arty`)
- `ARTY_CONFIG` — Config file name (default: `arty.yml`)

---

## Related Projects

Part of the [butter.sh](https://github.com/butter-sh) ecosystem:

- **[judge.sh](https://github.com/butter-sh/judge.sh)** — Testing framework with assertions and snapshots
- **[myst.sh](https://github.com/butter-sh/myst.sh)** — Mustache-style templating engine
- **[hammer.sh](https://github.com/butter-sh/hammer.sh)** — Project scaffolding tool
- **[leaf.sh](https://github.com/butter-sh/leaf.sh)** — Documentation generator
- **[whip.sh](https://github.com/butter-sh/whip.sh)** — Release management
- **[clean.sh](https://github.com/butter-sh/clean.sh)** — Linter and formatter

---

## License

MIT License — see [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

<div align="center">

**Part of the [butter.sh](https://github.com/butter-sh) ecosystem**

*Unlimited. Independent. Fresh.*

Crafted by [Valknar](https://github.com/valknarogg)

</div>
