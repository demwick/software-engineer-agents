#!/usr/bin/env bash
# Assertion helpers for evals. Sourced by suite scripts.
# SPDX-License-Identifier: AGPL-3.0-or-later

_fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    local expected="$1" actual="$2" message="${3:-assert_eq}"
    if [[ "$expected" != "$actual" ]]; then
        printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' \
            "$message" "$expected" "$actual" >&2
        exit 1
    fi
}
