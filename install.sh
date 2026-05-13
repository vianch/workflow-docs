#!/usr/bin/env bash
# install.sh — Installs the workflow-docs hook, agent, and skill into ~/.claude/.
# Safe to re-run. Merges into an existing settings.json instead of overwriting.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

echo "Installing into $CLAUDE_HOME"

mkdir -p "$CLAUDE_HOME/hooks" "$CLAUDE_HOME/agents" "$CLAUDE_HOME/skills" "$CLAUDE_HOME/workflow-docs"

# Hook scripts
install -m 755 "$SRC_DIR/hooks/open-workflow-docs.sh" "$CLAUDE_HOME/hooks/open-workflow-docs.sh"
echo "  hooks/open-workflow-docs.sh"
if [ -f "$SRC_DIR/hooks/log-activity.sh" ]; then
  install -m 755 "$SRC_DIR/hooks/log-activity.sh" "$CLAUDE_HOME/hooks/log-activity.sh"
  echo "  hooks/log-activity.sh"
fi
if [ -f "$SRC_DIR/hooks/workflow-docs-server.sh" ]; then
  install -m 755 "$SRC_DIR/hooks/workflow-docs-server.sh" "$CLAUDE_HOME/hooks/workflow-docs-server.sh"
  echo "  hooks/workflow-docs-server.sh"
fi
if [ -f "$SRC_DIR/hooks/bootstrap-flows.sh" ]; then
  install -m 755 "$SRC_DIR/hooks/bootstrap-flows.sh" "$CLAUDE_HOME/hooks/bootstrap-flows.sh"
  echo "  hooks/bootstrap-flows.sh"
fi

# Agent
install -m 644 "$SRC_DIR/agents/workflow-doc-generator.md" "$CLAUDE_HOME/agents/workflow-doc-generator.md"
echo "  agents/workflow-doc-generator.md"

# Skill
mkdir -p "$CLAUDE_HOME/skills/workflow-visualizer"
install -m 644 "$SRC_DIR/skills/workflow-visualizer/SKILL.md"          "$CLAUDE_HOME/skills/workflow-visualizer/SKILL.md"
install -m 644 "$SRC_DIR/skills/workflow-visualizer/template.html"     "$CLAUDE_HOME/skills/workflow-visualizer/template.html"
install -m 644 "$SRC_DIR/skills/workflow-visualizer/example-flows.json" "$CLAUDE_HOME/skills/workflow-visualizer/example-flows.json"
if [ -f "$SRC_DIR/skills/workflow-visualizer/PROMPT.md" ]; then
  install -m 644 "$SRC_DIR/skills/workflow-visualizer/PROMPT.md"       "$CLAUDE_HOME/skills/workflow-visualizer/PROMPT.md"
fi
echo "  skills/workflow-visualizer/{SKILL.md,PROMPT.md,template.html,example-flows.json}"

# workflow-kanban-task skill
mkdir -p "$CLAUDE_HOME/skills/workflow-kanban-task"
if [ -f "$SRC_DIR/skills/workflow-kanban-task/SKILL.md" ]; then
  install -m 644 "$SRC_DIR/skills/workflow-kanban-task/SKILL.md" "$CLAUDE_HOME/skills/workflow-kanban-task/SKILL.md"
  echo "  skills/workflow-kanban-task/SKILL.md"
fi

# settings.json — merge, don't overwrite
SETTINGS="$CLAUDE_HOME/settings.json"
FRAGMENT="$SRC_DIR/settings.json"

if [ ! -f "$SETTINGS" ]; then
  cp "$FRAGMENT" "$SETTINGS"
  echo "  settings.json (created)"
else
  BACKUP="$SETTINGS.bak.$(date +%s)"
  cp "$SETTINGS" "$BACKUP"
  if command -v jq >/dev/null 2>&1; then
    # Merge: keep existing keys; for hooks, deep-merge event arrays.
    TMP="$(mktemp)"
    jq -s '
      .[0] as $existing | .[1] as $fragment
      | $existing
      | .hooks = (
          ( $existing.hooks // {} ) as $eh
          | ( $fragment.hooks // {} ) as $fh
          | reduce ($fh | to_entries[]) as $kv ($eh;
              .[$kv.key] = ( (.[$kv.key] // []) + $kv.value )
            )
        )
    ' "$SETTINGS" "$FRAGMENT" > "$TMP"
    mv "$TMP" "$SETTINGS"
    echo "  settings.json (merged via jq; backup at $BACKUP)"
  else
    python3 - "$SETTINGS" "$FRAGMENT" <<'PY'
import json, sys
sp, fp = sys.argv[1], sys.argv[2]
with open(sp) as f: existing = json.load(f)
with open(fp) as f: fragment = json.load(f)
hooks = existing.get("hooks", {})
for evt, lst in fragment.get("hooks", {}).items():
    hooks.setdefault(evt, [])
    hooks[evt].extend(lst)
existing["hooks"] = hooks
with open(sp, "w") as f: json.dump(existing, f, indent=2)
PY
    echo "  settings.json (merged via python3; backup at $BACKUP)"
  fi
fi

echo
echo "Done. Next prompt in Claude Code will open:"
echo "  file://$CLAUDE_HOME/workflow-docs/index.html"
echo
echo "Override flows source by placing flows.json at one of:"
echo "  \$PWD/flows.json   |   \$PWD/.claude/flows.json   |   \$PWD/docs/flows.json"
