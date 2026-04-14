<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# Auto-QA Protocol (Detailed)

This is the extended reference for the auto-QA verification loop that
runs after `/sea-go` (and `/sea-quick`) executor finishes. SKILL.md
describes the basic flow; read this when you need the full semantics,
retry counter rules, host-compat integration, or failure recovery
protocol.

## The Marker File

`.sea/.needs-verify` is the single source of truth for "is there
work to verify?". It contains one integer — the current retry count
(starts at 0). Its **existence** tells the Stop hook to run; its
**contents** tell the hook how many retries have already been spent.

When you set it:

```bash
mkdir -p .sea && echo 0 > .sea/.needs-verify
```

When the Stop hook runs:

1. Marker absent → nothing to verify, Claude stops normally.
2. Marker present → hook proceeds to detection.

## Test Runner Detection

The hook calls `scripts/detect-test.sh` which checks in order:

| Signal | Command |
|--------|---------|
| `package.json` with `"test"` script + `bun.lock*` | `bun test` |
| `package.json` with `"test"` script + `pnpm-lock.yaml` | `pnpm test` |
| `package.json` with `"test"` script + `yarn.lock` | `yarn test` |
| `package.json` with `"test"` script (no lockfile) | `npm test` |
| `pyproject.toml` + `[tool.pytest]` or `pytest.ini` or `tests/` | `pytest` |
| `go.mod` | `go test ./...` |
| `Cargo.toml` | `cargo test` |
| `Makefile` with `^test:` target | `make test` |
| `Gemfile` mentioning rspec | `bundle exec rspec` |
| `mix.exs` | `mix test` |
| `deno.json` or `deno.jsonc` | `deno test` |

If no signal matches, the script exits 1 and auto-QA **auto-passes**
silently (no test runner is not a failure — fine for documentation
phases and very early MVPs).

## Retry Counter Semantics

```
attempt 0 → test runs → PASS → marker deleted, Claude stops
                      → FAIL → counter becomes 1, block decision, Claude auto-fixes
attempt 1 → test runs → PASS → marker deleted
                      → FAIL → counter becomes 2, block decision, Claude auto-fixes
attempt 2 → test runs → PASS → marker deleted
                      → FAIL → counter > 2, give up, block decision with give-up reason
```

A second give-up branch handles the rare case where `stop_hook_active`
is already `true` and the counter is ≥ 2 (loop-protection belt). Both
give-up branches emit the same `decision: block` JSON so Claude always
gets a reason, never silently stops on broken tests.

## Host-Compat Check (Post-Pass)

Even when tests pass, the hook runs `scripts/check-host-compat.sh`
before letting Claude stop. Currently checks:

- `pyproject.toml` `requires-python` vs `python3 --version` on host

If mismatched, it appends a warning to `.sea/.last-verify.log` and
returns a block decision. The reasoning: pytest can pass inside a
managed venv while `pip install -e .` fails on the user's host. The
test suite is not proof of packaging correctness.

Future host-compat checks (V1.2+): Node `engines.node`, Ruby
`required_ruby_version`, Go `go.mod` version directive.

## Failure Recovery Protocol

When the block decision reaches Claude, the reason becomes Claude's
next instruction. The reason **must be concrete and actionable** —
not "tests failed" but something like:

> Auto-QA: tests failed (attempt 1/2). Test command: pytest
>
> Last output:
> tests/test_storage.py::test_save FAILED
> AssertionError: expected 'high', got None in Todo.priority
>
> Read the full log at .sea/.last-verify.log, diagnose the root cause,
> and fix the failing tests. The Stop hook will re-verify automatically.

Claude then:
1. Reads `.sea/.last-verify.log`
2. Identifies the failing assertion / error
3. Fixes the code
4. The Stop hook fires again on the next response end
5. Loop repeats until PASS or give-up

## Do Not Invoke Verifier Manually

The `verifier` subagent exists as a documented interface, but in the
current architecture `/sea-go` never calls it directly. The `Stop`
hook handles auto-QA without subagent invocation — it's just bash +
`detect-test.sh`. Calling verifier manually would create a
double-verification loop and confuse the retry counter.
