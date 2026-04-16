<!--
  software-engineer-agents
  Copyright (C) 2026 demwick
  Licensed under the GNU Affero General Public License v3.0 or later.
  See LICENSE in the repository root for the full license text.
-->

# software-engineer-agents Plugin — Design Document

**Status:** Accepted — superseded by `docs/specs/2026-04-15-scope-and-state-refactor.md` for v2.0.0
**Last updated:** 2026-04-14

---

## Superseding note

This document describes the v1.0.0 design as shipped on 2026-04-14. For
v2.0.0 scope and state decisions, see
`docs/specs/2026-04-15-scope-and-state-refactor.md`. When that spec and
this one disagree, the spec wins.

The v1.0.0 content below is preserved as a historical record of the
original intent — it is still accurate for what shipped in v1.0.0 and
useful as context for "what the original plan was before the refactor".
It is intentionally left unedited.

---

## Vision

A **project completion engine** for solo developers. Get more done with less effort, keep the motivation to actually finish projects, detect gaps, and steer the user to the next action.

Three modes:

- **From-scratch MVP** — Capture idea → clarify → scaffold → split into phases → drive each phase to completion
- **Finish existing project** — Analyze codebase → find gaps → prioritize → roadmap → step the user through it
- **Single task** — Small job → direct execute + commit

## User Commands

| Command | Purpose | Model-invocable? |
|---------|---------|------------------|
| `/[name]:init` | Bootstrap project (new or existing) | **No** (side-effects) |
| `/[name]:go` | Run the next phase | **No** (side-effects) |
| `/[name]:quick` | Small task + commit | **No** (side-effects) |
| `/[name]:diagnose` | Health report | Yes |
| `/[name]:status` | Project status | Yes |
| `/[name]:roadmap` | Roadmap CRUD | Yes |

## Architectural Decisions

### 1. Thin Skills + Specialized Subagents (Approach B)

Skills are thin dispatchers: they read state, invoke the right agent, persist results. The heavy lifting lives in agents.

### 2. Cross-Session Memory — Built-in `memory:` field

Subagent frontmatter uses `memory: project`. The platform automatically manages `.claude/agent-memory/<agent>/MEMORY.md`. **No custom memory-manager agent.**

### 3. Auto-QA Loop — `Stop` hook with `type: "agent"`

No manual retry loop inside `/sea-go`. `hooks/hooks.json` has a `Stop` hook using `type: "agent"` that runs the `verifier` agent. If it returns `{ok: false, reason}`, Claude automatically continues. Native mechanism.

### 4. SessionStart Context Injection

A `SessionStart` hook with `matcher: "startup|resume"` reads `.sea/state.json` and `roadmap.md` and injects them via `hookSpecificOutput.additionalContext`. The user sees project state at session start without asking.

### 5. State Location — Hybrid

| What | Where | Why |
|------|-------|-----|
| Project state (roadmap, phase, plan-data) | `<project-root>/.sea/` | Visible, portable, gitignored |
| Agent learning (cross-session) | `.claude/agent-memory/<agent>/MEMORY.md` | Platform built-in via `memory: project` |
| Global preferences | `~/.claude/[name]/prefs.json` | Shared across all projects |

### 6. Token Efficiency

- `researcher`, `verifier` → **Haiku** (read-only, fast)
- `planner`, `executor` → **Sonnet** (complex judgment)
- Read-only agents never get Write/Edit (`disallowedTools` or explicit `tools` allowlist)

## Directory Layout

```
software-engineer-agents/
├── .claude-plugin/
│   └── plugin.json
├── DESIGN.md                   # this file
├── README.md
├── LICENSE
├── agents/
│   ├── researcher.md           # haiku, read-only, memory: project
│   ├── planner.md              # sonnet, read-only, memory: project
│   ├── executor.md             # sonnet, full tools, memory: project
│   └── verifier.md             # haiku, read-only + Bash, memory: project
├── skills/
│   ├── init/SKILL.md           # disable-model-invocation
│   ├── go/SKILL.md             # disable-model-invocation
│   ├── quick/SKILL.md          # disable-model-invocation
│   ├── diagnose/SKILL.md       # auto-invoke OK
│   ├── status/SKILL.md         # auto-invoke OK
│   └── roadmap/SKILL.md        # auto-invoke OK
├── hooks/
│   ├── hooks.json              # SessionStart + Stop
│   ├── run-hook.cmd            # polyglot wrapper (superpowers pattern)
│   └── session-start           # extensionless script (Windows quirk)
└── scripts/
    ├── state-tracker.sh        # file change / session end tracking
    └── detect-test.sh          # auto test runner detection
```

**Dropped from the original plan:** `memory-manager` agent, `scripts/memory-writer.sh`, `package.json` — we lean on platform built-ins instead.

## State File Layout (inside each project)

```
.sea/           # added to .gitignore
├── state.json          # current_phase, last_session, last_edit, last_verification
├── roadmap.md          # phase list (markdown, human-readable)
├── specs/              # phase specs with testable acceptance criteria (v3.1.0+)
│   └── phase-N.md
├── verification/       # Act feedback loop results (v3.1.0+)
│   └── phase-N.json
├── phases/
│   ├── phase-1/plan.md
│   └── phase-1/summary.md
└── diagnose.json       # latest health report
```

## Auto-QA Flow

```
User: /[name]:go
  ↓
Skill: read state → planner agent (writes spec + plan)
  ↓
Executor: TDD cycle per task (Red → Green → Refactor → Commit)
  ↓
Executor finishes work (Stop event fires)
  ↓
Stop hook: type="agent", prompt="run verifier, check tests & plan"
  ↓
Verifier: run tests + check spec criteria + TDD compliance
  → writes .sea/verification/phase-N.json
  → {ok: bool, reason: ...}
  ↓
ok=false → Claude auto-continues (retry)
ok=true  → Act decision:
           pass    → mark phase done, advance
           partial → surface unmet criteria, offer roadmap feedback
           fail    → block, stay in-progress
```

## Superpowers Compatibility

- We use our own skill namespace (`/[name]:*`)
- No conflicts with Superpowers skill names
- When Superpowers is installed, we can suggest `superpowers:writing-plans` for heavy plan/execute workflows

## Open Questions

- Plugin name: resolved — shipped as `software-engineer-agents` in v1.0.0 (v2.0.0 keeps the name)
- Marketplace distribution: post-V1
- MCP server: not in V1, optional later

---

## ADR-001: TDD + PDCA Hybrid Development Cycle (v3.1.0)

**Status:** Accepted
**Date:** 2026-04-16

### Context

The plugin drives software development through agents (planner → executor → verifier) but lacked two things: (1) a discipline that prevents the executor from writing untested code, and (2) a feedback loop that connects verification results back to the roadmap. Classic SDLC models (waterfall, V-model) are too heavyweight for a single-developer AI-assisted workflow.

### Decision

Adopt a two-layer cycle:

- **Inner loop (TDD):** every executor task follows Red → Green → Refactor. Failing test first, minimum implementation, cleanup while green. Bug fixes always produce two commits (test, then fix). Skip-path exists for docs/config via `[[ NO-TEST ]]` marker.
- **Outer loop (PDCA):** each phase is a Plan-Do-Check-Act iteration.
  - **Plan:** planner writes `.sea/specs/phase-N.md` (testable acceptance criteria) + `plan.md`
  - **Do:** executor runs TDD cycles per task
  - **Check:** verifier produces `.sea/verification/phase-N.json` with pass/partial/fail status, unmet criteria, TDD compliance, new findings
  - **Act:** `sea-go` reads verification result — pass advances, partial surfaces unmet criteria for roadmap feedback, fail blocks advancement. `state-tracker` hook persists verification metadata to `state.json`.

### Consequences

- Executor prompt is longer (~35 lines added). Token cost increase is negligible — executor runs on Sonnet with long contexts.
- Verifier now writes a JSON file (previously read-only except Bash). `tools:` allowlist unchanged — it uses `jq` via Bash.
- New state artifacts: `.sea/specs/`, `.sea/verification/`. Both documented in `docs/STATE.md`.
- `scripts/spec-validate.sh` and `scripts/validate-commit-msg.sh` added for deterministic validation.
- Backward compatible: pre-v3.1.0 phases without specs or verification files degrade gracefully with warnings.
