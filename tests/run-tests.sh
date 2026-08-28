#!/usr/bin/env bash
# Run every dopamine test script. One process per file so a crashing test
# cannot take the suite with it.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
failed=0
count=0

while IFS= read -r test; do
    count=$((count + 1))
    echo "=== ${test#"$SCRIPT_DIR"/}"
    if ! bash "$test"; then
        failed=$((failed + 1))
    fi
done < <(find "$SCRIPT_DIR" -name 'test-*.sh' -type f | sort)

echo
if [ "$failed" -eq 0 ]; then
    echo "all $count test file(s) passed"
    exit 0
fi
echo "$failed of $count test file(s) failed"
exit 1
