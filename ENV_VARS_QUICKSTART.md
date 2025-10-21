# Quick Start Guide: Environment Variables

This guide shows you how to use the new environment variables feature in arty.sh.

## 1. Basic Setup

Add an `envs` section to your `arty.yml`:

```yaml
name: "my-app"
version: "1.0.0"

envs:
  default:
    DATABASE_URL: "sqlite://./app.db"
    LOG_LEVEL: "info"

scripts:
  start: "python app.py"
```

Now when you run `arty start`, the environment variables will be automatically loaded.

## 2. Try the Demo

See the environment variables in action:

```bash
# View default environment
./arty.sh env/demo

# View development environment
ARTY_ENV=development ./arty.sh env/demo

# View production environment
ARTY_ENV=production ./arty.sh env/demo
```

## 3. Use in Your Scripts

Create a script that uses environment variables:

**my-script.sh:**
```bash
#!/usr/bin/env bash

echo "Running in $APP_ENV mode"
echo "Log level: $LOG_LEVEL"

if [ "$DEBUG" = "true" ]; then
    echo "Debug information..."
fi
```

**arty.yml:**
```yaml
envs:
  default:
    APP_ENV: "development"
    LOG_LEVEL: "debug"
    DEBUG: "true"

  production:
    APP_ENV: "production"
    LOG_LEVEL: "error"
    DEBUG: "false"

scripts:
  run: "bash my-script.sh"
```

**Usage:**
```bash
# Run with default (development) settings
arty run

# Run with production settings
ARTY_ENV=production arty run
```

## 4. Common Patterns

### API URLs by Environment

```yaml
envs:
  default:
    API_URL: "http://localhost:3000"
  
  staging:
    API_URL: "https://staging-api.myapp.com"
  
  production:
    API_URL: "https://api.myapp.com"

scripts:
  deploy: "curl -X POST $API_URL/deploy"
```

### Feature Flags

```yaml
envs:
  default:
    FEATURE_BETA: "false"
    FEATURE_ANALYTICS: "true"
  
  production:
    FEATURE_BETA: "true"
    FEATURE_ANALYTICS: "true"

scripts:
  test: "pytest tests/"
```

### Database Configuration

```yaml
envs:
  default:
    DB_HOST: "localhost"
    DB_PORT: "5432"
    DB_NAME: "myapp_dev"
  
  production:
    DB_HOST: "prod-db.myapp.com"
    DB_PORT: "5432"
    DB_NAME: "myapp_prod"

scripts:
  migrate: "python manage.py migrate"
```

## 5. Testing

Run the test suite to verify everything works:

```bash
# Run environment variable tests
arty test/env
```

## 6. Best Practices

1. **Always define a `default` environment** - This is loaded first and provides fallback values

2. **Use clear, descriptive names** - `API_URL` is better than `URL`

3. **Document your environments** - Add comments in `arty.yml` explaining what each environment is for

4. **Don't commit secrets** - Use environment variables for configuration, but keep secrets in a separate `.env` file that's not committed to git

5. **Test with different environments** - Make sure your scripts work in all defined environments

## 7. Troubleshooting

**Problem:** Variables aren't being set

**Solution:** Make sure you have `yq` installed:
```bash
# macOS
brew install yq

# Linux
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
chmod +x /usr/local/bin/yq
```

**Problem:** Variables from default are overriding pre-set values

**Solution:** This is intentional for named environments (development, production, etc.). If you need to preserve pre-set values, use the default environment or set them after running arty.

## Need Help?

Check out the full documentation in `ENV_VARS_README.md` or run:
```bash
arty help
```
