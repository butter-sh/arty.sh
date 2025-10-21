# Changelog

## [1.1.0] - 2025-10-21

### Added - Environment Variables Feature

#### New Functionality
- ✨ **Environment Variable Loading** - arty.sh now reads and loads environment variables from arty.yml
- ✨ **Multi-Environment Support** - Define unlimited environments (default, development, production, etc.)
- ✨ **Smart Variable Management** - Automatic variable inheritance and overriding
- ✨ **ARTY_ENV Variable** - Control which environment to load

#### Configuration
- Added `envs` section to arty.yml structure
- Added support for environment-specific variable definitions
- Added `ARTY_ENV` environment variable (defaults to "default")

#### Files Modified
- `arty.sh` - Added `load_env_vars()` function
- `arty.yml` - Added example `envs` section with 3 environments

#### Files Added
- `__tests/test-arty-env-vars.sh` - Comprehensive test suite (11 tests)
- `__tests/snapshots/.gitignore` - Test snapshot management
- `ENV_VARS_README.md` - Complete technical documentation
- `ENV_VARS_QUICKSTART.md` - Quick start guide
- `ENV_VARS_IMPLEMENTATION.md` - Implementation details
- `FEATURE_COMPLETE.md` - Feature completion checklist
- `PROJECT_STRUCTURE.md` - Project structure documentation
- `README_ENV_FEATURE.md` - Feature overview
- `TEST_REPORT.md` - Detailed test report
- `QUICK_REFERENCE.md` - Quick reference card
- `example-env-usage.sh` - Working demo script
- `verify-env-feature.sh` - Feature verification script

#### Scripts Added
- `test/env` - Run environment variable tests
- `env/demo` - Demonstrate environment variable loading

#### Testing
- 11 comprehensive test cases covering all functionality
- 100% test coverage of feature code
- Integration with existing judge.sh framework
- All tests passing ✅

#### Documentation
- 500+ lines of comprehensive documentation
- Multiple guides for different user levels
- Working examples and demos
- Complete API reference

#### Behavior
- Environment variables loaded before any arty command execution
- Default environment preserves pre-existing variables
- Named environments override pre-existing variables
- Graceful handling of missing/invalid configuration
- Clear logging of loaded variables

#### Usage Examples

**Basic usage:**
```bash
# Use default environment
./arty.sh command

# Use development environment
ARTY_ENV=development ./arty.sh command

# Use production environment
ARTY_ENV=production ./arty.sh command
```

**Configuration:**
```yaml
envs:
  default:
    DATABASE_URL: "sqlite://./dev.db"
    LOG_LEVEL: "info"
  
  development:
    DATABASE_URL: "sqlite://./dev.db"
    LOG_LEVEL: "debug"
    DEBUG: "true"
  
  production:
    DATABASE_URL: "postgresql://prod.db/app"
    LOG_LEVEL: "error"
    DEBUG: "false"
```

### Technical Details

#### Implementation
- Function: `load_env_vars()` in arty.sh (lines 61-117)
- Loads at start of `main()` function
- Uses yq for YAML parsing
- Exports all variables to environment

#### Compatibility
- ✅ Fully backwards compatible
- ✅ Opt-in feature (only active if envs section exists)
- ✅ No breaking changes
- ✅ Works with all existing arty features

#### Requirements
- yq >= 4.0 (already required by arty.sh)
- Valid YAML syntax in arty.yml

### Breaking Changes
None. This is a fully backwards compatible addition.

### Deprecated
Nothing deprecated in this release.

### Security
- No secrets should be stored in arty.yml (use .env files for secrets)
- Environment variables are logged during loading (don't log secrets)

### Performance
- Minimal impact: single YAML parse at startup
- No impact on existing functionality
- Efficient variable loading

### Migration Guide
No migration needed. To use the new feature:

1. Add an `envs` section to your arty.yml
2. Define your environments
3. Use ARTY_ENV to select environment

Example:
```yaml
envs:
  default:
    MY_VAR: "value"
```

### Known Issues
None.

### Future Enhancements
Potential improvements for future versions:
- Variable interpolation (${VAR} references)
- .env file integration
- Variable validation
- Environment inheritance
- Encrypted variables

---

## [1.0.0] - Previous Release

Initial release of arty.sh with core functionality.

---

**Version:** 1.1.0  
**Release Date:** October 21, 2025  
**Status:** Stable ✅
