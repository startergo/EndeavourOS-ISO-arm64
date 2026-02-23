#!/usr/bin/env bash
# Entrypoint script - ensure clean environment before running commands

# Kill any lingering gpg-agent processes
gpgconf --kill gpg-agent 2>/dev/null || true

# Update library cache
ldconfig

# Run the requested command
exec "$@"
