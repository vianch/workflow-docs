# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Claude Code plugin that renders an interactive swim-lane diagram of any app's architecture. It ships as a set of shell scripts, a subagent definition, a skill, and an HTML template — all installed into `~/.claude/`. No build step, no package manager.

## Install / uninstall

```bash
# Automated (from inside this folder)
mkdir -p /tmp/cwd-install
tar -xzf claude-workflow-docs.tar.gz -C /tmp/cwd-install
cd /tmp/cwd-install/claude-config
chmod +x install.sh hooks/open-workflow-docs.sh
./install.sh

# Uninstall
rm ~/.claude/hooks/open-workflow-docs.sh
rm ~/.claude/hooks/log-activity.sh
rm ~/.claude/hooks/workflow-docs-server.sh
rm ~/.claude/hooks/bootstrap-flows.sh
rm ~/.claude/agents/workflow-doc-generator.md
rm -rf ~/.claude/skills/workflow-visualizer
rm -rf ~/.claude/workflow-docs   # optional — generated output
# Restore settings.json from the backup the installer created:
# cp ~/.claude/settings.json.bak.<timestamp> ~/.claude/settings.json
```

## Testing changes manually

```bash
# Rebuild index.html and open Chrome (simulates SessionStart hook)
bash ~/.claude/hooks/open-workflow-docs.sh session-start

# Simulate UserPromptSubmit hook
bash ~/.claude/hooks/open-workflow-docs.sh user-prompt

# Tail live activity log
tail -f ~/.claude/workflow-docs/activity.jsonl

# Verify settings.json hook entries
jq '.hooks | keys' ~/.claude/settings.json

# Serve the docs dir over HTTP (what workflow-docs-server.sh does)
cd ~/.claude/workflow-docs && python3 -m http.server 47318
# then open http://localhost:47318
```

## Architecture

There is no runtime — everything is hook-driven. Claude Code fires shell hooks; the hooks build and open an HTML file.

```
repo/
├── install.sh                  # merges settings.json fragment into ~/.claude/settings.json
├── settings.json               # hook wiring fragment (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, SubagentStart, SubagentStop)
├── open-workflow-docs.sh       # SessionStart: resolves flows.json, rebuilds index.html, opens Chrome
├── bootstrap-flows.sh          # SessionStart (runs first): seeds per-project flows.json under ~/.claude on first visit
├── log-activity.sh             # Pre/PostToolUse + SubagentStart/Stop: appends JSONL to activity.jsonl
├── workflow-docs-server.sh     # SessionStart: idempotently starts python3 http.server on port 47318
├── agents/
│   └── workflow-doc-generator.md   # subagent definition — reads/writes flows.json, runs the hook
├── skills/
│   └── workflow-visualizer/
│       ├── SKILL.md            # agent-facing skill — owns schema, validation rules, rendering contract
│       ├── PROMPT.md           # canonical layout/look/interaction spec (source of truth)
│       ├── template.html       # single-file viewer (vanilla HTML/CSS/JS + SVG, no deps)
│       └── example-flows.json  # ToDesktop reference dataset
├── example-flows.json          # same file, top-level copy for easy reference
├── template.html               # same file, top-level copy
├── workflow-doc-generator.md   # same file, top-level copy
├── SKILL.md / PROMPT.md        # same files, top-level copies
└── claude-workflow-docs.tar.gz # all files in the nested layout install.sh expects
```

The tarball mirrors every file above in a `claude-config/` subdirectory tree. When updating any file, rebuild it:

```bash
cd /path/to/this/repo
tar -czf claude-workflow-docs.tar.gz \
  --transform 's|^|claude-config/|' \
  install.sh settings.json \
  hooks/open-workflow-docs.sh hooks/log-activity.sh \
  hooks/workflow-docs-server.sh hooks/bootstrap-flows.sh \
  agents/workflow-doc-generator.md \
  skills/workflow-visualizer/SKILL.md \
  skills/workflow-visualizer/PROMPT.md \
  skills/workflow-visualizer/template.html \
  skills/workflow-visualizer/example-flows.json
```

## flows.json resolution order (first wins)

1. `$PWD/flows.json`
2. `$PWD/.claude/flows.json`
3. `$PWD/docs/flows.json`
4. `~/.claude/workflow-docs/projects/<sha1-of-PWD>/flows.json` ← per-project sandbox, auto-created
5. `~/.claude/workflow-docs/flows.json`
6. bundled `example-flows.json`

## Key design constraints

- **PROMPT.md wins** — `template.html` is an implementation of `PROMPT.md`. If they conflict, fix the template to match the spec, not the other way around.
- **Never edit `template.html` per-project** — it is a shared skill asset. Project-specific data lives entirely in `flows.json`.
- **The tarball must stay in sync** — every change to a script or skill file must be followed by a tarball rebuild so the automated installer ships the latest version.
- **Hooks must always exit 0** — they run inside Claude Code and must never block a tool call.
- **`flows.json` is strict JSON** — no comments allowed (the schema docs use `jsonc` for readability only).

## flows.json schema (brief)

```json
{
  "app": { "name": "string", "description": "string" },
  "categories": [{ "id": "kebab", "label": "string", "color": "#rrggbb" }],
  "columns":    [{ "id": "kebab", "label": "UPPERCASE HEADER" }],
  "components": [{ "id": "kebab", "name": "string", "subtitle": "string", "column": "<columns.id>", "category": "<categories.id>", "paths": ["optional substring for live agent matching"] }],
  "flows": [{
    "id": "kebab", "name": "string", "description": "string", "category": "optional grouping",
    "steps": [{ "from": "<components.id>", "to": "<components.id>", "label": "imperative action", "detail": "one sentence" }]
  }]
}
```

Full example with every feature: `example-flows.json`.
