#!/bin/bash
# intel-smoke-test.sh - Smoke test on Intel Mac + macOS 15.7
# APPK-DFX-C02: Intel Mac installation test

set -euo pipefail

DMG_PATH="${1:-}"
if [ -z "$DMG_PATH" ]; then
    echo "Usage: $0 <path-to-AppKCode.dmg>"
    exit 1
fi

echo "=== Intel Mac Smoke Test ==="
echo "DMG: $DMG_PATH"
echo "Arch: $(uname -m)"
echo "macOS: $(sw_vers -productVersion)"

# Verify we're on Intel
if [ "$(uname -m)" != "x86_64" ]; then
    echo "FATAL: Not running on x86_64 (got $(uname -m))"
    exit 1
fi

# Mount DMG
MOUNT_POINT=$(hdiutil attach "$DMG_PATH" -nobrowse -quiet | tail -1 | awk '{print $NF}')
trap "hdiutil detach '$MOUNT_POINT' -quiet" EXIT

# Install app
APP_PATH="$MOUNT_POINT/AppKCode.app"
if [ ! -d "$APP_PATH" ]; then
    echo "FATAL: AppKCode.app not found in DMG"
    exit 1
fi

# Verify architecture
BINARY="$APP_PATH/Contents/MacOS/AppKCode"
FILE_INFO=$(file "$BINARY")
if ! echo "$FILE_INFO" | grep -q "x86_64"; then
    echo "FATAL: Binary is not x86_64"
    exit 1"echo "Arch check: PASSED"

# Launch app
echo "Launching AppKCode..."
open "$APP_PATH"
sleep 5

# Verify app is running
if ! pgrep -f "AppKCode" > /dev/null; then
    echo "FATAL: AppKCode did not start"
    exit 1
fi
echo "Launch: PASSED"

# Kill app
pkill -f "AppKCode"
sleep 2

echo "=== Smoke Test PASSED ==="
exit 0