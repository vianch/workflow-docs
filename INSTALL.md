# INSTALL — Claude Agents Visualizer

Two install paths. **Automated** is one command. **Manual** is six file copies and a two-key settings merge — no AI required, no scripts to trust.

If you've never touched `~/.claude/` before, skip to *Manual install* — it's the most explicit and the easiest to undo.

---

## Prerequisites

- macOS, Linux, or Windows (Git Bash / WSL)
- [Claude Code](https://docs.claude.com/en/docs/claude-code) installed and run at least once (so `~/.claude/` exists)
- Google Chrome (or Chromium) for the auto-open behaviour — optional; you can always open the page manually
- **`python3`** — required for the activity logger (timestamps), the index.html builder (JSON inlining), the local HTTP server (`python3 -m http.server`), and the session-start architecture-summary injector. macOS ships with it; on Linux install via your package manager.
- `jq` is optional but recommended (the installer falls back to `python3` for the `settings.json` merge if `jq` is missing).

---

## Automated install

From inside this folder (`claude-agents-visualizer/`):

```bash
# If you're working from the flat folder layout that ships in this repo,
# extract the bundled tarball first — install.sh expects nested directories.
mkdir -p /tmp/cwd-install
tar -xzf claude-workflow-docs.tar.gz -C /tmp/cwd-install
cd /tmp/cwd-install/claude-config

# Then run the installer.
chmod +x install.sh hooks/open-workflow-docs.sh
./install.sh
```

The installer:

1. Creates `~/.claude/{hooks,agents,skills,workflow-docs}/` if missing.
2. Copies the hook, subagent, and skill files (template + schema + example).
3. Merges its `settings.json` fragment into `~/.claude/settings.json` **without overwriting existing keys**. Uses `jq` if present, otherwise `python3`. Writes a timestamped backup at `~/.claude/settings.json.bak.<epoch>`.

Re-run it any time — it's idempotent for files, and the merge appends rather than duplicates wholesale (though running it three times will append three identical hook entries; check `jq '.hooks' ~/.claude/settings.json` if you re-run).

---

## Manual install (no AI, no installer)

This is the same thing the script does, written out. Copy the commands or do the copies by hand — both work.

### Step 1 — Create the directories

```bash
mkdir -p ~/.claude/hooks
mkdir -p ~/.claude/agents
mkdir -p ~/.claude/skills/workflow-visualizer
mkdir -p ~/.claude/workflow-docs
```

### Step 2 — Copy nine files from this folder into `~/.claude/`

Assuming your shell is in the `claude-agents-visualizer/` folder:

```bash
# Hooks
cp open-workflow-docs.sh      ~/.claude/hooks/open-workflow-docs.sh
cp log-activity.sh            ~/.claude/hooks/log-activity.sh
cp workflow-docs-server.sh    ~/.claude/hooks/workflow-docs-server.sh
cp bootstrap-flows.sh         ~/.claude/hooks/bootstrap-flows.sh
chmod +x ~/.claude/hooks/open-workflow-docs.sh \
         ~/.claude/hooks/log-activity.sh \
         ~/.claude/hooks/workflow-docs-server.sh \
         ~/.claude/hooks/bootstrap-flows.sh

# Subagent
cp workflow-doc-generator.md  ~/.claude/agents/workflow-doc-generator.md

# Skill (renderer + schema + canonical prompt + example)
cp SKILL.md                   ~/.claude/skills/workflow-visualizer/SKILL.md
cp PROMPT.md                  ~/.claude/skills/workflow-visualizer/PROMPT.md
cp template.html              ~/.claude/skills/workflow-visualizer/template.html
cp example-flows.json         ~/.claude/skills/workflow-visualizer/example-flows.json
```

That's the entirety of the file layout. Everything else (`workflow-docs/index.html`, `workflow-docs/flows.json`) is generated on first run.

### Step 3 — Add two hook entries to `~/.claude/settings.json`

#### Case A — you don't have a `~/.claude/settings.json` yet

Create it from the bundled fragment:

```bash
cp settings.json ~/.claude/settings.json
```

Done.

#### Case B — you already have one

**Back it up first:**

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak.$(date +%s)
```

Then open `~/.claude/settings.json` in your editor and **merge** these two entries into the existing `"hooks"` object. Don't replace the whole object — just add these keys alongside whatever is there:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/bootstrap-flows.sh session-start" }] },
      { "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/open-workflow-docs.sh session-start" }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/open-workflow-docs.sh user-prompt" }] },
      { "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/log-activity.sh user-prompt" }] }
    ],
    "PreToolUse": [
      { "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/log-activity.sh pre-tool-use" }] }
    ],
    "PostToolUse": [
      { "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/log-activity.sh post-tool-use" }] }
    ],
    "SubagentStart": [
      { "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/log-activity.sh subagent-start" }] }
    ],
    "SubagentStop": [
      { "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/log-activity.sh subagent-stop" }] }
    ]
  }
}
```

`SessionStart` runs in order — `bootstrap-flows.sh` first (architecture-summary injection + first-time bootstrap), then `open-workflow-docs.sh` (opens / refreshes the browser tab).

If `"hooks"` already has `SessionStart` or `UserPromptSubmit` arrays, **append** the inner `{ "hooks": [...] }` object to the existing array rather than replacing it. Order doesn't matter.

A final, merged `settings.json` typically looks like this (with whatever else you had — `statusLine`, `theme`, other `PreToolUse` hooks, plugins, etc. — preserved untouched):

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "/path/to/your-existing-hook.sh" }] }
    ],
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/open-workflow-docs.sh session-start" }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/open-workflow-docs.sh user-prompt" }] }
    ]
  },
  "theme": "dark-ansi"
}
```

### Step 4 — Verify

```bash
test -x ~/.claude/hooks/open-workflow-docs.sh                       && echo "hook OK"
test -f ~/.claude/agents/workflow-doc-generator.md                  && echo "agent OK"
test -f ~/.claude/skills/workflow-visualizer/SKILL.md               && echo "skill SKILL.md OK"
test -f ~/.claude/skills/workflow-visualizer/template.html          && echo "skill template.html OK"
test -f ~/.claude/skills/workflow-visualizer/example-flows.json     && echo "skill example-flows.json OK"
```

If you have `jq`:

```bash
jq '.hooks | keys' ~/.claude/settings.json
# must include "SessionStart" and "UserPromptSubmit"
```

Without `jq`, eyeball the file in your editor.

### Step 5 — Generate the rendered page

```bash
bash ~/.claude/hooks/open-workflow-docs.sh session-start
```

This should now exist:

```
~/.claude/workflow-docs/index.html
~/.claude/workflow-docs/flows.json
```

(On macOS the script also tries to open Chrome to the page. That's optional — failure is non-fatal.)

---

## Open the demo

Open the rendered file directly in your browser to confirm the install:

```bash
# macOS
open "file://$HOME/.claude/workflow-docs/index.html"

# Linux
xdg-open "file://$HOME/.claude/workflow-docs/index.html"

# Windows (Git Bash)
start "" "file://$HOME/.claude/workflow-docs/index.html"
```

You should see:

- The example app's name in the top bar.
- A graph of packages in the centre canvas.
- A list of flows on the left (e.g. *Invite new user*, *Sign in*).
- Click a flow → its path lights up, unrelated nodes dim, the right-hand panel lists each numbered step with its annotation.

If the page renders blank, **make sure you ran the hook at least once** (Step 5) — that's what builds `index.html` with the inlined data needed for `file://` to work without CORS errors.

```bash
bash ~/.claude/hooks/open-workflow-docs.sh session-start
```

If you'd rather serve over HTTP (and get live reload as `flows.json` changes), run:

```bash
cd ~/.claude/workflow-docs && python3 -m http.server 8765
# then open http://localhost:8765
```

---

## After install: try it out in Claude Code

Open Claude Code in any project and say:

```
Add a flow for "User login" between web-app, api-gateway, and auth-service.
```

The `workflow-doc-generator` subagent should route automatically, write/update `flows.json`, and refresh `~/.claude/workflow-docs/index.html`. Reload the browser tab to see the new flow.

---

## Uninstall

```bash
# Remove the four installed files
rm ~/.claude/hooks/open-workflow-docs.sh
rm ~/.claude/agents/workflow-doc-generator.md
rm -rf ~/.claude/skills/workflow-visualizer
rm -rf ~/.claude/workflow-docs    # generated output — optional to keep

# Remove the two hook entries from settings.json
# Easiest: restore the backup the installer created
ls ~/.claude/settings.json.bak.*  # find your backup
cp ~/.claude/settings.json.bak.<timestamp> ~/.claude/settings.json
```

Or just delete the `SessionStart` and `UserPromptSubmit` entries from `~/.claude/settings.json` by hand.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| No Chrome tab opens on session start | Hook not registered, or Chrome not installed | `jq '.hooks.SessionStart' ~/.claude/settings.json` — should return an array containing the open-workflow-docs entry. Or just open `file://$HOME/.claude/workflow-docs/index.html` yourself. |
| `index.html` doesn't exist | Hook never ran | Run `bash ~/.claude/hooks/open-workflow-docs.sh session-start` once manually. |
| Page loads but graph is empty / blank | `index.html` was built before the CORS-bootstrap fix landed, or `python3` was missing when the hook ran | Re-run `bash ~/.claude/hooks/open-workflow-docs.sh session-start` (rebuilds with the inline bootstrap). Make sure `python3` is on `PATH`. |
| `Failed to fetch` / CORS errors in console | Old `index.html` without inline bootstrap | Delete `~/.claude/workflow-docs/index.html` and re-run the hook. |
| `install.sh` complains about missing `hooks/` or `agents/` subfolders | You ran it from the flat folder layout | Extract `claude-workflow-docs.tar.gz` first (see *Automated install*). |
| `command not found: jq` and no `python3` | Installer can't merge into existing `settings.json` | Use the *Manual install* path — merge by hand in your editor. |
| Re-running `install.sh` duplicated my hook entries | Merge is append-only | Edit `settings.json` and delete duplicates, or restore from the backup at `~/.claude/settings.json.bak.<timestamp>`. |
