#!/usr/bin/env bash
# Symlink this repo's skills and agents into ~/.claude and ~/.codex.
# Safe to re-run; never overwrites real files.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"

link() { # link <target> <link-path>
  if [ -L "$2" ]; then ln -sfn "$1" "$2"
  elif [ -e "$2" ]; then echo "skip: $2 exists and is not a symlink"; return
  else ln -s "$1" "$2"; fi
  echo "linked: $2"
}

mkdir -p ~/.claude/skills ~/.claude/agents ~/.codex/skills ~/.codex/agents
for d in "$REPO"/skills/*/; do
  n=$(basename "$d")
  link "$REPO/skills/$n" ~/.claude/skills/"$n"
  link "$REPO/skills/$n" ~/.codex/skills/"$n"
done
for f in "$REPO"/claude/agents/*.md; do link "$f" ~/.claude/agents/"$(basename "$f")"; done
for f in "$REPO"/codex/agents/*.toml; do
  n=$(basename "$f" .toml)
  link "$f" ~/.codex/agents/"$n".toml
done
