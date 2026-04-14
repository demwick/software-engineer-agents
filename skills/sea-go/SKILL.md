---
name: sea-go
description: Advance a SEA-managed project by exactly one phase — read roadmap, pick next pending phase, plan it if needed, run executor, let the auto-QA Stop hook verify. **This is the main SEA command** — use it aggressively whenever the user says any of "continue", "go", "next step", "keep going", "advance", "run the next phase", "do the next thing", "work on the project", or whenever the user has a SEA project in progress and wants forward motion. Also the default response when the user says "continue where we left off" in a session with an active .sea/state.json.
argument-hint: [optional phase number or "next"]
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

<!--
  software-engineer-agent
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# /sea-go

Advance the project by one phase. Announce at the start: **"Using the go skill to run the next phase."**

Argument: $ARGUMENTS (optional — a phase number, or empty = next pending phase)

## Step 1: Preconditions

1. Check `.sea/state.json` and `.sea/roadmap.md` exist.
   - If missing → tell the user *"No project state found. Run /sea-init first."* and stop.
2. Read both files.

## Step 2: Pick the Phase

- If $ARGUMENTS is a number → use that phase (error out if it's already done or doesn't exist).
- Otherwise → use the first phase whose status is `pending` or `in-progress`.
- If every phase is `done` → celebrate briefly and tell the user the project is complete. Stop.

Show the user: *"Starting Phase N: <name>"* before continuing.

## Step 3: Plan the Phase (if no plan yet)

Check `.sea/phases/phase-N/plan.md`.

- **Plan exists** → read it, skip to Step 4.
- **No plan** → launch the `planner` agent in **Mode B (Phase Planning)**. Pass the roadmap entry for Phase N as context. The planner writes `.sea/phases/phase-N/plan.md`.

Read the plan. If it contains any `[[ ASK: ... ]]` markers, surface those questions to the user and stop. Do not guess.

## Step 4: Choose the Pipeline

The plan's "Complexity" line tells you which pipeline to run:

| Complexity | Pipeline |
|------------|----------|
| trivial | `executor` only |
| medium | `executor` only (verifier runs via Stop hook) |
| complex | `researcher` → `executor` (verifier runs via Stop hook) |

For **complex** only: before calling executor, launch the `researcher` agent with the plan's context section to gather any deep knowledge the executor will need. Read the report yourself — do not dump it to the user.

## Step 5: Execute

Before launching, check `.sea/phases/phase-N/progress.json`:

- **Exists** → read it. The phase was interrupted mid-execution. Tell the user *"Resuming Phase N from task <current_task> (tasks <completed_tasks> already done)."*
- **Absent** → fresh start.

Launch the `executor` agent. Pass it:
- The path to the plan file
- The plan's context section
- Any researcher findings (for complex phases)
- **Resume context** if `progress.json` existed: *"Skip tasks <completed_tasks>; resume at task <current_task>."*

Wait for executor to finish. It returns `STATUS: done` or `STATUS: blocked`.

- **blocked** → surface executor's report to the user verbatim, mark the phase `in-progress` in state.json, stop.
- **done** → arm auto-QA (next step).

## Step 6: Arm the Auto-QA Hook

Before your response ends, run this from the project root:

```bash
mkdir -p .sea && echo 0 > .sea/.needs-verify
```

This creates the `.needs-verify` marker file. The `Stop` hook (`hooks/auto-qa`) checks for this marker when your response finishes. If it exists:

1. The hook auto-detects the project's test runner via `scripts/detect-test.sh`
2. Runs the tests
3. On **pass** → clears the marker, Claude stops normally
4. On **fail** → returns `{"decision": "block", "reason": "..."}`, Claude automatically continues to fix the failures (up to 2 retries, then the hook gives up)

You do NOT invoke the verifier agent manually. The hook handles it. Trust the hook.

If the project has no test runner, the hook auto-passes silently — fine for `/sea-quick` work and very early MVPs.

## Step 7: Update State and Report

On verifier success:

1. Update `.sea/state.json` via the `state-update.sh` helper — **never write state.json directly with Write/Edit**. The helper jq-merges, preserves required fields (`schema_version`, `mode`, `created`), auto-refreshes `last_session`, and validates the result:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/state-update.sh" \
       current_phase=<N+1> \
       last_commit=<short-sha-of-HEAD>
   ```
   Pass any additional fields as extra `KEY=VALUE` args. JSON-parseable values (numbers, booleans, arrays) keep their type; everything else becomes a string.
2. Update `.sea/roadmap.md`: mark Phase N as `done`.
3. Write a short summary to `.sea/phases/phase-N/summary.md`:
   ```markdown
   # Phase N Summary
   Completed: <ISO now>
   Commits: <count>
   Files touched: <list>
   Notes: <2-3 sentences>
   ```
4. Tell the user:
   > Phase N complete. Next: Phase N+1 "<name>". Run `/sea-go` when ready.

## Rules

- **Do not skip the planner** for medium/complex phases, even if the phase "looks obvious". The plan is the contract the executor works against.
- **Do not run verifier yourself** — the Stop hook does it. Calling it manually creates a double-verification loop.
- **Respect blockers** — if executor reports `blocked`, do not try to unstick it; surface it to the user.
- **One phase per /sea-go invocation.** Do not chain phases.
- **Never delete or rewrite commits** the executor made. If something's wrong, the next phase or a `/sea-quick` fixes it.
