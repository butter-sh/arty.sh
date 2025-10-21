# Environment Variables Feature

## Overview

arty.sh now supports loading environment variables from the `arty.yml` configuration file. This allows you to define different sets of environment variables for different environments (development, production, staging, etc.) and easily switch between them.

## Configuration

Add an `envs` section to your `arty.yml`:

```yaml
name: "my-project"
version: "1.0.0"

# Environment variables
envs:
  default:
    APP_ENV: "default"
    LOG_LEVEL: "info"
    DEBUG: "false"
  
  development:
    APP_ENV: "development"
    LOG_LEVEL: "debug"
    DEBUG: "true"
    API_URL: "http://localhost:3000"
  
  production:
    APP_ENV: "production"
    LOG_LEVEL: "warn"
    DEBUG: "false"
    API_URL: "https://api.production.com"

scripts:
  test: "bash test.sh"
```

## Usage

### Default Environment

By default, arty.sh loads the `default` environment:

```bash
arty test
# Loads: APP_ENV=default, LOG_LEVEL=info, DEBUG=false
```

### Specific Environment

Use the `ARTY_ENV` environment variable to select a different environment:

```bash
ARTY_ENV=development arty test
# Loads: APP_ENV=development, LOG_LEVEL=debug, DEBUG=true, API_URL=http://localhost:3000

ARTY_ENV=production arty test
# Loads: APP_ENV=production, LOG_LEVEL=warn, DEBUG=false, API_URL=https://api.production.com
```

## Behavior

1. **Loading Order**: 
   - First, `default` environment variables are loaded
   - Then, if a different environment is specified, those variables override the defaults

2. **Preservation of Existing Variables**:
   - In the `default` environment, pre-existing environment variables are NOT overridden
   - In named environments (development, production, etc.), variables ARE overridden

3. **Availability**: 
   - All loaded environment variables are available to scripts defined in `arty.yml`
   - Variables are exported and available to child processes

## Examples

### Use in Scripts

```yaml
envs:
  default:
    DATABASE_URL: "sqlite://./dev.db"
  production:
    DATABASE_URL: "postgresql://prod.example.com/db"

scripts:
  migrate: "python manage.py migrate --database=$DATABASE_URL"
```

Then run:
```bash
# Use development database
arty migrate

# Use production database
ARTY_ENV=production arty migrate
```

### Multiple Environments

```yaml
envs:
  default:
    TIMEOUT: "30"
    RETRIES: "3"
  
  ci:
    TIMEOUT: "60"
    RETRIES: "5"
    CI: "true"
  
  staging:
    TIMEOUT: "45"
    API_URL: "https://staging-api.example.com"
  
  production:
    TIMEOUT: "30"
    API_URL: "https://api.example.com"
```

## Testing

The environment variables feature includes a comprehensive test suite located at `__tests/test-arty-env-vars.sh`.

Run the tests:
```bash
# Run environment variable tests
arty test/env

# Or directly
bash __tests/test-arty-env-vars.sh
```

## Implementation Details

- Environment variables are loaded before any arty command is executed
- The `load_env_vars()` function is called early in the `main()` function
- Uses `yq` to parse the YAML configuration
- Logs which environment is being loaded and which variables are set

## Requirements

- `yq` must be installed (arty.sh already requires this)
- Valid YAML syntax in `arty.yml`

## Notes

- If no `envs` section exists in `arty.yml`, arty.sh continues to work normally
- Invalid YAML in the `envs` section triggers a warning but doesn't stop execution
- Environment variable names should follow standard naming conventions (uppercase, underscores)
