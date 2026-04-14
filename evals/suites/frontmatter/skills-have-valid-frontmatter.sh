#!/usr/bin/env bash
# Validate that every skills/*/SKILL.md has required frontmatter fields.
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$REPO_ROOT/evals/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import glob
import os
import sys

import yaml

repo = sys.argv[1]
errors = []

for path in sorted(glob.glob(os.path.join(repo, "skills", "*", "SKILL.md"))):
    with open(path) as f:
        text = f.read()

    if not text.startswith("---\n"):
        errors.append(f"{path}: does not start with '---'")
        continue

    end = text.find("\n---", 4)
    if end == -1:
        errors.append(f"{path}: frontmatter closing '---' not found")
        continue

    fm = yaml.safe_load(text[4:end])
    if not isinstance(fm, dict):
        errors.append(f"{path}: frontmatter did not parse as a mapping")
        continue

    for field in ("name", "description"):
        if field not in fm:
            errors.append(f"{path}: missing required field '{field}'")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)

print(f"OK: {len(glob.glob(os.path.join(repo, 'skills', '*', 'SKILL.md')))} skill(s) validated")
PY
