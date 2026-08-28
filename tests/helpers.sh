#!/usr/bin/env bash
# Shared assertions for dopamine's test scripts. Source this, then call
# `finish` last: it sets the exit status from the failure count.
#
# Every assertion prints one line so a failing run says which case broke
# without the reader opening the test file.

FAILURES=0

pass() { echo "  [PASS] $1"; }

fail() {
    echo "  [FAIL] $1"
    shift
    for line in "$@"; do echo "      $line"; done
    FAILURES=$((FAILURES + 1))
}

assert_eq() {
    local description="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$description"
    else
        fail "$description" "expected: $expected" "actual:   $actual"
    fi
}

assert_contains() {
    local description="$1" haystack="$2" needle="$3"
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        pass "$description"
    else
        fail "$description" "missing: $needle" "in: $haystack"
    fi
}

assert_not_contains() {
    local description="$1" haystack="$2" needle="$3"
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        fail "$description" "unexpectedly present: $needle" "in: $haystack"
    else
        pass "$description"
    fi
}

# assert_exit DESCRIPTION EXPECTED_CODE COMMAND...
assert_exit() {
    local description="$1" expected="$2"
    shift 2
    local rc=0
    "$@" >/dev/null 2>&1 || rc=$?
    assert_eq "$description" "$expected" "$rc"
}

finish() {
    if [ "$FAILURES" -eq 0 ]; then
        echo "OK"
        exit 0
    fi
    echo "$FAILURES failure(s)"
    exit 1
}
