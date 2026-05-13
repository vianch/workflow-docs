#!/usr/bin/env bash
# bootstrap-flows.sh
# On the first Claude Code session in a new project, create a per-project
# flows.json under $HOME/.claude/workflow-docs/projects/<cwd-hash>/ and nudge
# the main agent to populate it via the workflow-doc-generator subagent.
#
# Wired into SessionStart BEFORE open-workflow-docs.sh.
#
# The file lives under ~/.claude (NOT in the user's repo) so there is zero
# project pollution. After the subagent generates the real diagram, it
# removes the .needs-generation marker so future sessions don't re-nudge.

set -u

TRIGGER="${1:-session-start}"

# Skip everything that isn't a session start — nothing else should bootstrap.
[ "$TRIGGER" = "session-start" ] || exit 0

# Skip degenerate cwds: $HOME itself, and ~/.claude (the visualizer's own home).
if [ "$PWD" = "$HOME" ] || [ "$PWD" = "$HOME/.claude" ] || [ "${#PWD}" -lt 5 ]; then
  exit 0
fi

CWD_HASH="$(printf '%s' "$PWD" | shasum 2>/dev/null | awk '{print $1}')"
[ -z "$CWD_HASH" ] && CWD_HASH="$(printf '%s' "$PWD" | md5sum 2>/dev/null | awk '{print $1}')"
[ -z "$CWD_HASH" ] && CWD_HASH="$(printf '%s' "$PWD" | md5 2>/dev/null)"
[ -z "$CWD_HASH" ] && CWD_HASH="default"

DOCS_DIR="$HOME/.claude/workflow-docs"
PROJECT_DIR="$DOCS_DIR/projects/$CWD_HASH"
PROJECT_FLOWS="$PROJECT_DIR/flows.json"
PROJECT_META="$PROJECT_DIR/.meta"
PROJECT_NEEDS_GEN="$PROJECT_DIR/.needs-generation"
EXAMPLE_FLOWS="$HOME/.claude/skills/workflow-visualizer/example-flows.json"

# If any project-level flows.json already exists, we're not on a first session.
for c in "$PWD/flows.json" "$PWD/.claude/flows.json" "$PWD/docs/flows.json" "$PROJECT_FLOWS"; do
  if [ -f "$c" ]; then
    exit 0
  fi
done

# First time in this project — set up the per-project sandbox.
mkdir -p "$PROJECT_DIR" 2>/dev/null || exit 0

if [ ! -f "$PROJECT_FLOWS" ] && [ -f "$EXAMPLE_FLOWS" ]; then
  cp "$EXAMPLE_FLOWS" "$PROJECT_FLOWS" 2>/dev/null || true
  printf '{"created_at":"%s","cwd":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PWD" > "$PROJECT_META" 2>/dev/null || true
  touch "$PROJECT_NEEDS_GEN" 2>/dev/null || true

  # Hint the main agent. Claude Code reads SessionStart hookSpecificOutput.
  # additionalContext into the session, so the agent will see this on turn 0.
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"📋 workflow-visualizer: first session in $PWD — created a starter flows.json at $PROJECT_FLOWS (under ~/.claude, NOT in the repo). It is seeded with the bundled example as a placeholder.\n\nPlease invoke the **workflow-doc-generator** subagent now to inventory this codebase and replace the placeholder with the real architecture (categories, columns, components, flows). When the subagent finishes writing $PROJECT_FLOWS, delete the marker $PROJECT_NEEDS_GEN so future sessions don't re-nudge."}}
EOF
fi

exit 0
