---
name: workflow-visualizer
description: Use whenever the user wants to document, visualize, or update the workflows between packages or components of an application as a single-page HTML diagram. Triggers include "document flows", "visualize the architecture", "show how X works across packages", "map the data flow for action Y", "create flows.json", "regenerate workflow docs", or requests to build/edit an interactive package interaction diagram. Owns the canonical schema for flows.json and the single-file HTML template that renders it as a dark-navy swim-lane diagram with gold-accented numbered step arrows.
---

# Workflow Visualizer

This skill owns:

1. The **canonical spec** in `PROMPT.md` — the source-of-truth instructions an AI must follow when generating the diagram. Layout, look & feel, interaction, and data model. *Do not deviate.*
2. The `flows.json` schema (categories, columns, components, flows) that documents what an application does.
3. `template.html` — a single self-contained HTML viewer (vanilla HTML/CSS/JS + SVG). No external dependencies, works offline from `file://`.
4. `example-flows.json` — a reference dataset (ToDesktop-flavoured) demonstrating every schema feature.

## When to use this skill

Use the skill any time the user wants to:

- Create a new `flows.json` for an app.
- Add, edit, or remove a component or workflow.
- Visualize an existing JSON with the standard template.
- Explain how data moves between components for a specific action.

For sustained work on an app's docs, prefer invoking the `workflow-doc-generator` subagent — it wraps this skill with project-resolution logic and validation.

## File locations (per the hook contract)

- Source of truth (project): `flows.json` resolved in this order:
  1. `$PWD/flows.json` — committed to the repo, shared with the team.
  2. `$PWD/.claude/flows.json` — typically gitignored, project-local.
  3. `$PWD/docs/flows.json` — alongside the rest of project docs.
  4. `$HOME/.claude/workflow-docs/projects/<cwd-hash>/flows.json` — **per-project sandbox under `~/.claude`** (zero project pollution). Auto-created on first session in a new project by the `bootstrap-flows.sh` hook.
  5. `$HOME/.claude/workflow-docs/flows.json` — global fallback.
  6. Falls back to the bundled `example-flows.json`.
- Rendered output: `$HOME/.claude/workflow-docs/index.html` (single self-contained file with JSON inlined).
- Template: `$HOME/.claude/skills/workflow-visualizer/template.html` (this skill).
- Canonical spec: `$HOME/.claude/skills/workflow-visualizer/PROMPT.md`.

### Per-project auto-bootstrap

When you start a new Claude Code session in a directory that has no `flows.json` anywhere on the priority chain, the `bootstrap-flows.sh` hook fires and:

1. Creates `~/.claude/workflow-docs/projects/<cwd-hash>/flows.json` seeded from the bundled example.
2. Drops a `.needs-generation` marker in the same directory.
3. Emits a `SessionStart` context message asking the main agent to invoke the **`workflow-doc-generator`** subagent immediately, replace the placeholder with the real architecture, and delete the marker when done.

This keeps every project diagram private to your machine (under `~/.claude`, not in the repo) unless you explicitly ask to promote it to `$PWD/flows.json`.

The template has a `<script type="application/json" id="flows-data">__FLOWS_JSON__</script>` placeholder; the hook (`$HOME/.claude/hooks/open-workflow-docs.sh`) replaces `__FLOWS_JSON__` with the JSON content so the page is fully self-contained.

## Canonical flows.json schema

```jsonc
{
  "app":        { "name": "string", "description": "one-line subtitle" },
  "categories": [
    { "id": "kebab", "label": "Human readable", "color": "#rrggbb" }
  ],
  "columns":    [
    { "id": "kebab", "label": "UPPERCASE LANE HEADER" }
  ],
  "components": [
    {
      "id":       "kebab-unique",
      "name":     "monospace name",     // rendered in monospace inside the card
      "subtitle": "short caption",      // smaller sans-serif line under the name
      "column":   "<columns.id>",       // which lane it sits in
      "category": "<categories.id>",    // category tint + legend swatch
      "paths":    ["packages/cli/"]     // optional — substrings matched against
                                        // tool targets so the "Live agents"
                                        // pane pulses this card when the agent
                                        // touches files/URLs/commands containing
                                        // any of these strings
    }
  ],
  "flows": [
    {
      "id":          "kebab-unique",
      "name":        "Human readable action",
      "description": "One line that fits in the sidebar",
      "category":    "optional sidebar grouping",
      "steps": [
        {
          "from":   "<components.id>",
          "to":     "<components.id>",
          "label":  "imperative action — POST /v1/invites or publishRelease()",
          "detail": "short prose: what's passed, where the code lives, edge cases"
        }
      ]
    }
  ]
}
```

### Suggested column spine

Left-to-right, in request-flow direction:

```
Actors → Client surfaces → Backend/functions → Storage/data → Pipeline → Distribution → External services
```

Adapt the labels to the app, but keep the tiering.

### Suggested category palette

| Category id      | Colour            | Use for |
| ---------------- | ----------------- | ------- |
| `actor`          | `#f472b6` pink    | Humans / external systems initiating flows |
| `client`         | `#22d3ee` cyan    | Frontends / CLIs / browser apps |
| `firebase-fn`    | `#a78bfa` violet  | Backend functions / service code |
| `firebase-data`  | `#fb923c` orange  | Data stores |
| `pipeline`       | `#34d399` green   | Build / CI / processing |
| `distribution`   | `#60a5fa` blue    | CDN / edge / workers |
| `external`       | `#9ca3af` gray    | Third-party APIs the app calls |

### Annotation style

`step.label` is read at a glance from the diagram. Write it like a log line, not like prose:

- ✅ `POST /v1/invites { email, role } → 201 { inviteId }`
- ✅ `publish event "user.invited" to SNS`
- ✅ `useInviteUser() → graphql mutation inviteUser($input)`
- ❌ `Sends a request to the API` (too vague)
- ❌ `The web app does some processing and then talks to the auth service` (narrative, not data)

`step.detail` is the prose line beneath: one sentence on what changes, where the code lives, or a non-obvious side-effect.

### Validation rules

Refuse to write JSON that fails any of these:

- Every `step.from` and `step.to` must reference an existing `components[].id`.
- Every `component.column` must reference an existing `columns[].id`.
- Every `component.category` must reference an existing `categories[].id`.
- `id` values are unique within `categories[]`, `columns[]`, `components[]`, and `flows[]`.
- `categories`, `columns`, `components`, and `flows` are non-empty.
- `steps` is non-empty for each flow.

### Backwards compatibility

The renderer also accepts an older `packages` schema (with `package.label`, `step.annotation`, `step.payload`) and normalises it at load time. Always **write new files in the canonical schema** above — the old format is for read-compat only.

## Rendering contract (what template.html does)

The template implements `PROMPT.md` literally. Three regions:

1. **Top header** — title, one-line subtitle, horizontal legend of category swatches.
2. **Main area (~75% width)** — vertical swim lanes left-to-right by tier. Each column has a small uppercase header and a vertical divider. Each component is a card with a monospace name and small subtitle. Cards are tinted on the left edge by their category colour.
3. **Right sidebar (~25% width)**, two stacked panels:
   - **FLOWS (top)** — scrollable, searchable, click to select. Bolded name + one-line description.
   - **STEPS (bottom)** — empty until a flow is selected. Then shows numbered, ordered steps with `from → to` route, action label, and short detail.

When a flow is selected: involved cards stay bright (yellow tint + glow), others dim to ~20% opacity, curved SVG bezier arrows render between cards in step order with gold circular step-number badges at each arrow's midpoint. Bidirectional step pairs (A→B and B→A) curve in opposite directions. Self-actions (`from === to`) place the badge directly on the card.

Click the same flow again to clear, or use the "Clear selection" button. Arrows redraw on window resize.

The template is fully self-contained: vanilla HTML/CSS/JS, custom SVG arrow rendering, no external CDN, no build step.

## How to apply the skill

1. Decide where `flows.json` lives. Default to `$PWD/flows.json` for project-level docs.
2. If creating from scratch, **read `PROMPT.md` first**, then copy `example-flows.json` as a starting point and adapt.
3. Inventory components by reading the project. Use `Glob`/`Grep` to find package boundaries (`packages/*/package.json`, top-level service folders, monorepo workspaces, `firebase.json`, `terraform/**`).
4. For each flow the user asks about, walk the call sites and write one step per component boundary crossed. Include payload shapes when they are knowable from the code.
5. Validate against the rules above before writing.
6. Refresh the output via the hook (it inlines the JSON into `index.html`):
   ```bash
   bash $HOME/.claude/hooks/open-workflow-docs.sh session-start
   ```
   On macOS the hook also opens Chrome.

## Editing rules

- **Never** edit `template.html` to suit a single project. If a rendering change is needed across all apps, edit the skill's template and the hook will propagate it.
- **Never** invent components that are not in the codebase. If unsure, read first.
- **Never** deviate from `PROMPT.md` for layout, look & feel, or interaction. That document wins.

## Themes

Two built-in themes, selectable via the toggle button in the top-right of the canvas (sun ↔ moon, animated). Persisted in `localStorage` under `workflow-docs-theme`. Defaults to dark.

- **`shades-of-purple`** (default, dark) — navy/indigo backgrounds, gold accent, green for live activity.
- **`ayu-light`** (light) — warm off-white, orange accent, green for live activity.

Both palettes are declared as CSS variables in two `[data-theme="…"]` blocks at the top of `template.html`. Adding a third theme is a matter of duplicating one block, renaming, and shipping new colour values.

## Resizable layout

- The right sidebar (`aside.side`) is horizontally resizable from **280 px to 480 px** via a drag handle on its left edge.
- Each of the three panes (Flows / Steps / Agents+Activity) is vertically resizable via drag handles between them, with an 80 px minimum per pane.
- All sizes persist in `localStorage` under `workflow-docs-layout`.

## Everything is live (over HTTP)

When opened from `http://127.0.0.1:<port>/` (the default), three independent live loops are running:

| Loop | Source | Cadence |
| --- | --- | --- |
| **Flows / steps / board** | `flows.json` (symlinked to the resolved source) | every 1 s |
| **Live agents pane** | `activity.jsonl` (appended to by hook) | every 800 ms |
| **Component pulse** | new activity rows matched against `component.paths[]` | event-driven |

Edits to `$PWD/flows.json` (or any of the resolved source paths) propagate to the diagram within ~1 s with no hook fire required — the docs dir's `flows.json` is a symlink, so the page sees source edits directly. Tool calls fired by any agent in any Claude Code session writing to the same machine appear in the Live agents pane within ~800 ms.

Opened from `file://` you keep the static snapshot baked into `index.html` at hook-fire time — no live loops, no live agents.

## Agents tab vs Activity tab

The bottom pane has two tabs:

- **Agents** (default) — one card per known agent. For each: status dot (running / idle / done), name (monospaced), tool count + time since start, goal (italic — pulled from the `UserPromptSubmit` payload for the main agent, or from the spawning `Task` tool's `prompt` field for subagents), and the most recent tool + target.
- **Activity** — full chronological event feed (timestamp, agent name, tool pill, target). Spawn events are highlighted in green.

Both are fed by the same `activity.jsonl` stream. The hook captures:

| Hook event | Logged as | Fields |
| --- | --- | --- |
| `UserPromptSubmit` | `user-prompt` | sets `main`'s goal |
| `PreToolUse` (`tool=Task`) | `spawn` (synthetic) + `pre-tool-use` | sets the subagent's goal |
| `PreToolUse` / `PostToolUse` | `pre-tool-use` / `post-tool-use` | tool + target |
| `SubagentStart` / `SubagentStop` | `subagent-start` / `subagent-stop` | status transitions |

## Live agents pane

When the page is served from `http://127.0.0.1:<port>/` (the included `workflow-docs-server.sh` hook brings this up automatically on session start), a third right-side pane appears: **Live agents**. It polls `./activity.jsonl` every ~800ms and shows the last 80 events with timestamp, agent name, tool, and target.

Each event is matched against every component's `paths[]` (longest substring wins). On match, that card briefly pulses gold. Components with no `paths` simply don't pulse — they still appear in the diagram. Match patterns are plain substrings, not globs: `packages/cli/` matches any file path containing that string, `todesktop build` matches any Bash command line containing it, `https://api.stripe.com` matches that URL.

Events come from four hook types — `PreToolUse`, `PostToolUse`, `SubagentStart`, `SubagentStop`. The agent name on each event is the subagent type when it's a subagent event, and `main` otherwise. Logged tools include Read, Write, Edit, Bash, Glob, Grep, WebFetch, plus anything else Claude Code runs.

If the page is opened directly from `file://`, the pane shows an "offline (open via http://)" message — `fetch` is blocked under CORS so live polling doesn't work. The hook's open script automatically picks the HTTP URL when the server is up.

## Reference files

- `PROMPT.md` — canonical spec, copy-pasteable into a fresh chat to regenerate the template from scratch.
- `example-flows.json` — full example demonstrating every schema feature, including self-actions, bidirectional steps, and `paths` for live agent matching.
- `template.html` — the renderer. Treat as read-only from this skill's perspective unless a cross-project rendering change is needed.
