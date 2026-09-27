#!/bin/bash
# arch-check.sh - Verify x86_64 architecture of build products
# Hard constraint H1: All binaries must be x86_64, not arm64e

set -euo pipefail

BINARY="${1:-.build/release/AppKCode}"
VIOLATIONS=()

echo "Checking architecture of: $BINARY"

# Check main binary
FILE_INFO=$(file "$BINARY")
echo "  $FILE_INFO"

if echo "$FILE_INFO" | grep -q "arm64e"; then
    VIOLATIONS+=("$BINARY contains arm64e slice (violates H1)")
fi

if ! echo "$FILE_INFO" | grep -q "x86_64"; then
    VIOLATIONS+=("$BINARY missing x86_64 slice (violates H1)")
fi

# Check all linked dylibs/frameworks
if command -v otool &> /dev/null; then
    DYLIBS=$(otool -L "$BINARY" 2>/dev/null | grep -v "$BINARY" | awk '{print $1}' | sort -u)
    for dylib in $DYLIBS; do
        if [[ -f "$dylib" ]]; then
            LIPO_INFO=$(lipo -info "$dylib" 2>/dev/null || echo "unknown")
            if echo "$LIPO_INFO" | grep -q "arm64" && ! echo "$LIPO_INFO" | grep -q "x86_64"; then
                VIOLATIONS+=("Dependency $dylib only provides arm64 (violates H1)")
            fi
        fi
    done
fi

if [ ${#VIOLATIONS[@]} -gt 0 ]; then
    echo "ARCH CHECK FAILED - Violations:"
    for v in "${VIOLATIONS[@]}"; do
        echo "  - $v"
    done
    exit 1
fi

echo "ARCH CHECK PASSED - All binaries are x86_64"
exit 0