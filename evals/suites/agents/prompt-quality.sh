#!/usr/bin/env bash
# Asserts prompt-quality patterns are installed in agent files.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# Rule 7 present in _common.md
grep -q 'Evidence-Bearing Exit Reports' agents/_common.md \
  || fail "_common.md missing Rule 7 (Evidence-Bearing Exit Reports)"

# Each write-critical agent has Step 0 comprehension check
for agent in researcher planner executor; do
  grep -q 'Demonstrate Comprehension' "agents/${agent}.md" \
    || fail "${agent}.md missing Step 0 (Demonstrate Comprehension)"
  grep -q 'UNDERSTOOD:' "agents/${agent}.md" \
    || fail "${agent}.md missing UNDERSTOOD: output format"
done

# verifier.md intentionally skipped — no Step 0 by design
if grep -q 'Demonstrate Comprehension' agents/verifier.md 2>/dev/null; then
  fail "verifier.md should NOT have Step 0 — it is intentionally excluded"
fi

echo "prompt-quality.sh: all checks passed"
