# Environment Variables - Quick Reference

## Configuration

```yaml
# arty.yml
envs:
  default:
    VAR_NAME: "value"
  
  development:
    VAR_NAME: "dev_value"
  
  production:
    VAR_NAME: "prod_value"
```

## Usage

```bash
# Use default environment
./arty.sh command

# Use specific environment
ARTY_ENV=development ./arty.sh command
ARTY_ENV=production ./arty.sh command
```

## Common Patterns

### Database URLs
```yaml
envs:
  default:
    DATABASE_URL: "sqlite://./dev.db"
  production:
    DATABASE_URL: "postgresql://prod.db/app"
```

### API Endpoints
```yaml
envs:
  default:
    API_URL: "http://localhost:3000"
  staging:
    API_URL: "https://staging-api.example.com"
  production:
    API_URL: "https://api.example.com"
```

### Feature Flags
```yaml
envs:
  default:
    FEATURE_BETA: "false"
  staging:
    FEATURE_BETA: "true"
```

### Log Levels
```yaml
envs:
  default:
    LOG_LEVEL: "debug"
  production:
    LOG_LEVEL: "error"
```

## Commands

```bash
# View demo
./arty.sh env/demo

# Different environments
ARTY_ENV=development ./arty.sh env/demo
ARTY_ENV=production ./arty.sh env/demo

# Run tests
./arty.sh test/env

# Verify feature
bash verify-env-feature.sh
```

## In Scripts

Variables are automatically available:

```yaml
scripts:
  deploy: "curl -X POST $API_URL/deploy"
  migrate: "python manage.py migrate --db=$DATABASE_URL"
  start: "LOG_LEVEL=$LOG_LEVEL python app.py"
```

## Behavior

| Aspect | Behavior |
|--------|----------|
| **Default env** | Loads first, preserves existing vars |
| **Named env** | Overrides defaults and existing vars |
| **Missing section** | Silent (no error) |
| **Invalid YAML** | Warning, continues execution |
| **Missing var** | Empty string |

## Tips

✅ **DO:**
- Always define a `default` environment
- Use descriptive variable names
- Document your environments
- Test with different environments

❌ **DON'T:**
- Commit secrets to arty.yml
- Use lowercase variable names
- Mix different naming conventions

## Troubleshooting

**Variables not set?**
- Check yq is installed: `yq --version`
- Verify YAML syntax: `yq eval '.envs' arty.yml`
- Check loading message in output

**Wrong environment loaded?**
- Verify ARTY_ENV is set correctly
- Check environment name in arty.yml
- Use lowercase environment names

**Variables not in scripts?**
- Ensure envs section is before scripts
- Check variable names match exactly
- Verify variables are exported

## Documentation

- **Quick Start:** ENV_VARS_QUICKSTART.md
- **Full Docs:** ENV_VARS_README.md
- **Tests:** __tests/test-arty-env-vars.sh
- **Examples:** example-env-usage.sh

## Support

```bash
# Get help
./arty.sh help

# View configuration
yq eval '.envs' arty.yml

# Test your setup
./arty.sh test/env
```

---

**Feature Version:** 1.0.0  
**Status:** Production Ready ✅
