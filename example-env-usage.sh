#!/usr/bin/env bash

# example-env-usage.sh
# Demonstrates how to use environment variables loaded from arty.yml

echo "================================"
echo "Environment Variables Demo"
echo "================================"
echo ""
echo "Current Environment: ${APP_ENV:-not set}"
echo "Log Level: ${LOG_LEVEL:-not set}"
echo "Debug Mode: ${DEBUG:-not set}"
echo "API URL: ${API_URL:-not set}"
echo ""
echo "All environment variables starting with APP_, LOG_, DEBUG, or API_:"
env | grep -E '^(APP_|LOG_|DEBUG|API_)' | sort
echo ""
echo "================================"
