---
name: implement-review
description: Run an implement → review loop with an implementer subagent and a code-reviewer subagent, one task set at a time, committing after each. Use when the user asks to "implement and review", "spin up an implementer and a reviewer", or to execute an implementation plan task set by task set. Accepts an inline task or a plan file, optional task-set selection, and mode=manual (default) or mode=auto.
---

# Implement → Review loop

You are the orchestrator. You do not write code yourself — you delegate to two subagents and make the calls between them:

- **implementer** — writes and stages the change.
- **code-reviewer** — reviews the staged change and reports findings with severities (`critical`, `major`, `minor`, `nit`).

Start each subagent fresh. The reviewer must never get the implementer's reasoning — only the spec and the diff.

## Inputs

Parse from the user's request:

- **Work**: an inline task, or a plan file path. For a plan, the task sets to run (default: all, in plan order). If the plan has no clear task-set boundaries, propose a split and confirm it before starting.
- **Mode**: `manual` (default) or `auto`.

## Preflight

1. `git status`. If anything is already staged, stop and ask — every commit must contain only this run's work.
2. Note untracked and modified files that exist now; they are not yours and must never be staged.
3. Read `git log --oneline -15` to learn the repo's commit message convention.
4. Note the repo's instruction files (`AGENTS.md`, `CLAUDE.md`) — pass their paths to both subagents.

## Per task set

### 1. Implement

Spawn the implementer with:

- The task set text verbatim, plus the plan path for surrounding context.
- The repo instruction file paths.
- "Stage only the files you changed, by explicit path (`git add <path>`). Never `git add -A` or `git add .`. Do not commit."

### 2. Review

Spawn the code-reviewer with:

- The task set text as the spec it must meet.
- "Review the staged change: `git diff --cached`."
- In auto mode, also: "Triage each finding with a Decision (`fix` or `skip`) using these rules: `critical` and `major` → fix. `minor` → fix if cheap and inside this task set's scope, else skip. `nit` → skip unless it is a one-line change that is clearly right."

### 3. Decide

**Manual mode**

1. Show the user the implementer's report and the reviewer's findings, then stop and wait.
2. Apply what the user picks: send the chosen findings to a fresh implementer, which fixes and re-stages.
3. Commit (see below) and move to the next task set.

**Auto mode**

1. Collect the findings marked `fix`. If you can show from the code that a finding is wrong, you may reject it — record why.
2. Send the rest to a fresh implementer; it fixes and re-stages.
3. Re-run the reviewer on the staged diff, telling it which findings were fixed so it checks those and anything the fix touched.
4. Repeat at most 2 fix rounds. If a `critical` is still open after that, stop the run: do not commit, report.
5. Commit and move on.

**Stop the run in auto mode** (report and hand back to the user) when: tests or lint fail and the implementer cannot fix them, a `critical` is unresolved, the plan is ambiguous in a way that changes the design, or the next step is destructive (dropping data, running migrations against a shared DB, force operations).

### 4. Commit

- Check `git diff --cached --name-only` contains only files this task set changed.
- One commit per task set, message in the repo's convention, describing the task set.
- Never push, never amend earlier commits, never skip hooks. If a pre-commit hook rewrites files, re-stage them and commit again.

## Report

At the end (or when stopping early), print the report inline — no file:

```
## Run summary
Mode: auto | manual · Task sets: N done / M total · Stopped early: no | yes — <why>

### Task set 1: <title> — <commit sha>
Files: <paths>
Verification: <commands run → pass/fail>
| Severity | Finding | Decision | Reason |
|---|---|---|---|
| major | file.ts:42 — … | fixed | … |
| nit | … | skipped | … |

### Open items
- <anything unresolved, skipped findings worth revisiting, assumptions the implementer made>
```
