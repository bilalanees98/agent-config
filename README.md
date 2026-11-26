# agent-config

Personal skills and subagent definitions for Claude Code and Codex.

```
skills/<name>/SKILL.md     shared — same format for both tools
claude/agents/<name>.md    Claude subagents
codex/agents/<name>.toml   Codex subagents (hand-copied from the Claude prompts; not auto-synced)
install.sh                 symlinks everything into ~/.claude and ~/.codex
```

## Install

```bash
./install.sh
```

Re-run after adding a skill or agent. It only creates or updates symlinks; a real file in the way is skipped and reported.

## Adding things

- **Skill:** add `skills/<name>/SKILL.md` (optionally `agents/openai.yaml` for Codex UI metadata), run `./install.sh`. Both tools pick it up.
- **Agent:** add `claude/agents/<name>.md` and, if Codex needs it too, `codex/agents/<name>.toml` with `name`, `description`, `developer_instructions`, then run `./install.sh`.
- Editing a Claude agent prompt does not update its Codex copy. Update both by hand when it matters.

## What's here

- `implement-review` skill — implementer → reviewer loop over a task or an implementation plan, one task set at a time, committing each. `mode=manual` (default) pauses for you after every review; `mode=auto` lets the reviewer's severity triage decide what gets fixed. Ends with an inline report of findings and decisions.
  - Claude: `/implement-review docs/plan.md mode=auto`
  - Codex: `$implement-review docs/plan.md mode=auto`
- `spec-english` skill — prose output in ASD-STE100 Simplified Technical English. Intensity 0–100, default 80; stays on until "stop spec-english".
  - Claude: `/spec-english` or `/spec-english 100`
  - Codex: `$spec-english` or `$spec-english 100`
- `independent-security-review` skill — read-only security gate for a diff, branch, PR, paths, or repo. Traces what protects each entry point, keeps only findings with a concrete exploit path, ends with `block` / `pass-with-findings` / `pass`. Options: `surface=backend|frontend|fullstack|auto`, `effort=low|medium|high`, `format=markdown|json`. Can be the rubric for the `code-reviewer` agent.
  - Claude: `/independent-security-review effort=high`
  - Codex: `$independent-security-review effort=high`
- `implementer`, `code-reviewer` agents — used by the skill; also usable on their own.
