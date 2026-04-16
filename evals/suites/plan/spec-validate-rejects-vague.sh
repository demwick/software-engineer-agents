#!/usr/bin/env bash
# Verify spec-validate.sh rejects vague criteria and accepts valid specs.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$REPO_ROOT/evals/lib/assert.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Test 1: valid spec passes
cat > "$TMPDIR/valid.md" << 'SPEC'
# Phase 1 Spec: Auth System

## Goal
Add JWT-based authentication to the API.

## Acceptance Criteria
- [ ] POST /api/login returns 200 with a JWT token for valid credentials
- [ ] GET /api/protected returns 401 without a valid Authorization header
- [ ] JWT tokens expire after 15 minutes

## Out of Scope
- OAuth integration
- Password reset flow
SPEC

bash "$REPO_ROOT/scripts/spec-validate.sh" "$TMPDIR/valid.md" >/dev/null
echo "PASS: valid spec accepted"

# Test 2: missing Goal section → exit 2
cat > "$TMPDIR/no-goal.md" << 'SPEC'
# Phase 1 Spec: Something

## Acceptance Criteria
- [ ] thing one works
- [ ] thing two works

## Out of Scope
- nothing
SPEC

assert_exit_code 2 bash "$REPO_ROOT/scripts/spec-validate.sh" "$TMPDIR/no-goal.md"
echo "PASS: missing Goal rejected"

# Test 3: fewer than 2 criteria → exit 3
cat > "$TMPDIR/few-criteria.md" << 'SPEC'
# Phase 1 Spec: Tiny

## Goal
Do one thing.

## Acceptance Criteria
- only one criterion

## Out of Scope
- everything else
SPEC

assert_exit_code 3 bash "$REPO_ROOT/scripts/spec-validate.sh" "$TMPDIR/few-criteria.md"
echo "PASS: too few criteria rejected"

# Test 3b: AC-style criteria accepted
cat > "$TMPDIR/ac-style.md" << 'SPEC'
# Phase 1 Spec: AC Style

## Goal
Test AC format.

## Acceptance Criteria
- AC1: first criterion passes some check
- AC2: second criterion passes another check

## Out of Scope
- nothing
SPEC

bash "$REPO_ROOT/scripts/spec-validate.sh" "$TMPDIR/ac-style.md" >/dev/null
echo "PASS: AC-style criteria accepted"

# Test 4: vague criteria → exit 4
cat > "$TMPDIR/vague.md" << 'SPEC'
# Phase 1 Spec: Vague

## Goal
Make it work.

## Acceptance Criteria
- the feature works correctly
- users can log in

## Out of Scope
- nothing
SPEC

assert_exit_code 4 bash "$REPO_ROOT/scripts/spec-validate.sh" "$TMPDIR/vague.md"
echo "PASS: vague criteria rejected"

# Test 5: file not found → exit 1
assert_exit_code 1 bash "$REPO_ROOT/scripts/spec-validate.sh" "$TMPDIR/nonexistent.md"
echo "PASS: missing file rejected"
