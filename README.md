# Claude Agents Visualizer

An interactive, single-page diagram of how the packages and components of your application talk to each other — driven by a small `flows.json` file. Vertical swim lanes for the tiers, dark-navy theme, gold-accented numbered step arrows.

It plugs into Claude Code as a hook + subagent + skill, so the diagram opens automatically in Chrome at the start of every session, and you can ask Claude (in plain English) to add or edit flows.

> **TL;DR** — Describe your architecture once in `flows.json`. Get a clickable diagram that shows, for each "user action" (invite a user, reset password, checkout, etc.), the exact path data takes across your components, with annotations on every hop.

The canonical generation spec lives in [`PROMPT.md`](./PROMPT.md) — paste it into a fresh Claude/ChatGPT session and ask it to document any app, and you'll get the same diagram style.

---

## Why it exists

Most architecture diagrams rot. They live in Figma or Lucidchart, drift away from the code, and answer only one question ("what does the system look like?") instead of the question engineers actually have:

> *"When a user does X, which packages get called and what data flows between them?"*

This tool answers that question. Each **flow** is a named user action with a sequence of **steps** (`from → to` with a `label` + `detail`), and the diagram highlights the exact path when you click it.

It's small enough to live next to your code, version-controlled as JSON, and editable by an AI agent that understands your repo.

---

## What you get

- **Interactive swim-lane diagram** — vertical lanes for *Actors → Client surfaces → Backend/functions → Storage/data → Pipeline → Distribution → External services*, components rendered as monospace-named cards tinted by their category colour.
- **Click-to-highlight per flow** — involved cards stay bright, others dim to 20%, curved SVG bezier arrows draw between cards with gold step-number badges at each arrow's midpoint.
- **Live agents pane** — two-tab bottom panel: **Agents** shows each running agent with its goal (the user prompt for `main`, the `Task` tool prompt for subagents), tool count, status, and most-recent tool. **Activity** shows the full chronological event stream.
- **Kanban board** — an **Architecture | Kanban** tab toggle in the main canvas showing **Planned / In Dev / Done** columns. Uses a two-tier data source: explicit `TodoWrite` task data when available, or a live synthesized view derived from the agents activity stream as a fallback — so the board is never empty.
- **Live trail on the board** — when no manual flow is selected, the agent's recent path through your components is drawn as dashed green arrows with numbered badges; touched cards glow green, untouched ones dim.
- **Architecture in Claude's memory** — on every session start, `bootstrap-flows.sh` reads your project's `flows.json` and emits a compact summary (app, lanes, components, flows) as `SessionStart.additionalContext`. The agent sees the architecture from turn 0 of every conversation without you having to remind it. Typical cost: 500–1500 tokens per session.
- **Themes** — toggle dark (`shades-of-purple`) ↔ light (`ayu-light`) via the animated sun/moon switch in the canvas toolbar. Defaults to dark, persisted in `localStorage`.
- **Resizable layout** — the sidebar resizes horizontally (280–480 px); the three panes resize vertically. All sizes persisted.
- **Live flows / steps / board** — when opened over HTTP (the default), the diagram polls a symlinked `flows.json` every 1 s. Edit `flows.json` in your editor and the lanes, cards, flows list, and selected steps update in place without a refresh.
- **JSON source of truth** — a small `flows.json` schema you can keep in your repo (`./flows.json`, `./.claude/flows.json`, or `./docs/flows.json`).
- **Single self-contained file** — the output `index.html` has all data inlined, works offline from `file://`. When opened via the bundled local HTTP server, it also live-polls activity.
- **Auto-open on session start** — every Claude Code session opens a Chrome tab to the local diagram.
- **AI editing** — a subagent (`workflow-doc-generator`) and skill (`workflow-visualizer`) that let you say *"add a flow for password reset"* and have the JSON updated, validated, and re-rendered.

---

## How it fits together

```
~/.claude/
├── settings.json                                  # hook config merged in
├── hooks/
│   ├── open-workflow-docs.sh                      # opens Chrome on SessionStart / UserPromptSubmit
│   ├── workflow-docs-server.sh                    # ensures local HTTP server (for live activity polling)
│   └── log-activity.sh                            # appends one JSONL event per tool call
├── agents/
│   └── workflow-doc-generator.md                  # subagent: creates/edits flows.json
├── skills/
│   └── workflow-visualizer/
│       ├── SKILL.md                               # agent-facing rules + schema
│       ├── PROMPT.md                              # canonical generation spec (the source-of-truth)
│       ├── template.html                          # single-file viewer (vanilla HTML/CSS/JS + SVG)
│       └── example-flows.json                     # reference dataset
└── workflow-docs/                                 # generated at runtime
    ├── index.html                                 # single self-contained file (JSON inlined)
    ├── flows.json
    ├── activity.jsonl                             # rolling tail of recent tool events
    ├── .server.pid                                # background python http.server PID
    └── .server.port                               # port (default 47318, override WORKFLOW_DOCS_PORT)
```

| Piece | Role |
|---|---|
| `hooks/open-workflow-docs.sh` | Opens Chrome on `SessionStart`. On `UserPromptSubmit`, rebuilds the per-project `index.html` under `projects/<slug>/` if `flows.json` or the template changed. Each project gets its own URL (`http://127.0.0.1:<port>/projects/<slug>/index.html`) so opening Claude Code in different repos never clobbers each other's tabs. Falls back to `file://` when the server isn't up. |
| `hooks/workflow-docs-server.sh` | Idempotently brings up a `python3 -m http.server` on port `47318` (override `WORKFLOW_DOCS_PORT`) serving `~/.claude/workflow-docs/`. Required for the Live agents pane. |
| `hooks/log-activity.sh` | Wired to `PreToolUse` / `PostToolUse` / `SubagentStart` / `SubagentStop`. Appends one JSONL event per tool call to `activity.jsonl` (rolling 500-line tail). |
| `agents/workflow-doc-generator.md` | Subagent auto-routed when you ask Claude Code to add/edit/visualize a workflow. Reads/writes `flows.json`, validates the schema, refreshes the output. |
| `skills/workflow-visualizer/` | Owns `PROMPT.md` (the canonical spec), the JSON schema, the template, and an example. Editable in one place to update every project's diagram. |

---

## Install

Two options:

- **Automated (recommended)** — run `./install.sh`. See [INSTALL.md](./INSTALL.md) → *Automated install*.
- **Manual (no AI, no script)** — copy seven files, merge two settings keys, done. See [INSTALL.md](./INSTALL.md) → *Manual install*.

Either way, the next Claude Code session opens `file://$HOME/.claude/workflow-docs/index.html` automatically.

---

## Quick demo

After installing, the bundled `example-flows.json` documents the ToDesktop architecture (Electron CLI build/release pipeline, Firebase Functions, Azure Pipelines, Stripe webhook, invite flow). Open it directly:

```bash
open "file://$HOME/.claude/workflow-docs/index.html"        # macOS
xdg-open "file://$HOME/.claude/workflow-docs/index.html"    # Linux
```

If the file doesn't exist yet, run the hook once manually to generate it:

```bash
bash ~/.claude/hooks/open-workflow-docs.sh session-start
```

Click any flow on the right (e.g. *todesktop build (Electron CLI)*) — the cards along its path light up, others dim, and numbered yellow arrows draw between them in step order.

---

## Using it in Claude Code

Once installed, in any session:

```
Add a flow for "Reset password" between web-app, api-gateway,
auth-service, notifications-service, and sendgrid.
```

The `workflow-doc-generator` subagent will:

1. Resolve `flows.json` (looking in `$PWD/flows.json`, `$PWD/.claude/flows.json`, `$PWD/docs/flows.json`, then `~/.claude/workflow-docs/flows.json`).
2. Add the new flow with one step per component boundary.
3. Validate the schema (every `from`/`to` references an existing component, every component's `column`/`category` exists, IDs unique, no empty flows).
4. Refresh `~/.claude/workflow-docs/index.html` with the inlined JSON.

You can also call it explicitly: *"Use the `workflow-doc-generator` subagent to map the checkout flow."*

---

## Running the workflow from a Claude Code prompt

You drive everything from natural-language prompts inside `claude` (the CLI). No commands to memorise.

### Start a session

```bash
cd /path/to/your/project
claude
```

The hook fires on session start and opens `file://$HOME/.claude/workflow-docs/index.html` in Chrome.

### Prompt patterns that work well

**Create a brand-new `flows.json` for the current project**

```
Inventory the components in this repo and create a flows.json at the project root.
Use the canonical schema (categories / columns / components / flows). Start with
two flows: the most common write path and the most common read path.
```

**Add a single flow**

```
Add a flow called "Invite new user" that goes:
admin-browser → web-app → fn-auth → firestore,
then fn-auth → postmark, then invitee-browser → web-app → fn-auth.
Annotate each hop with the actual endpoint or function name.
```

**Edit an existing flow**

```
In the "Checkout" flow, the payments-service now calls Stripe via the new
/v2/intents endpoint. Update the step label and detail.
```

**Add a new component and wire it into a flow**

```
We just added a fraud-check service that sits between api-gateway and
payments-service on the checkout path. Add it to flows.json (column:
"backend", category: "service") and update the Checkout flow to route
through it.
```

**Explain a flow back to you** (read-only — no edits)

```
Walk me through the "Reset password" flow step by step. For each hop,
point to the file in this repo where that call is made.
```

**Force a re-render** (e.g. after editing `flows.json` by hand)

```bash
bash ~/.claude/hooks/open-workflow-docs.sh session-start
```

### Tell Claude exactly which subagent to use

If routing ever feels off, name it explicitly:

```
Use the workflow-doc-generator subagent to add a flow for "Refund order".
```

### Managing Kanban tasks with the `workflow-kanban-task` skill

The `workflow-kanban-task` skill lets you manage the board in plain English. Claude routes to it automatically whenever you use task-related phrasing. No commands, no IDs to remember.

**Create tasks:**
```
add a task: implement the auth refresh flow
add high priority task: fix the billing webhook
add a task for cleaning up the CSS
```

**Move tasks:**
```
start the auth task        → moves it to In Dev
move billing task to in dev
```

**Complete tasks:**
```
done with the CSS task
mark auth refresh as done
complete the billing webhook
```

**List the board:**
```
show tasks
what's on the board
list kanban
```

**Remove tasks:**
```
remove the CSS cleanup task
delete task t-3
clear all done tasks
```

The skill reads and writes `~/.claude/workflow-docs/projects/<slug>/tasks.json` directly. The board reflects every change within 1 second.

### Populating the Kanban board

The Kanban tab is always live — it shows a synthesized view of running agents from the moment activity starts. But for richer cards with explicit task descriptions and priorities, ask Claude to plan first using `TodoWrite`:

```
Before starting, write out a todo list for everything you need to do.
```

or:

```
Plan this work as tasks first, then execute.
```

Once the agent calls `TodoWrite`, the board shows the explicit task list with full descriptions and `High` / `Medium` / `Low` priority badges. Cards no longer carry the green `live` badge. The board updates within 1 s of every `TodoWrite` call.

**Two-tier data source at a glance:**

| Source | When active | What you see |
|---|---|---|
| `TodoWrite` (explicit) | After asking Claude to plan | Exact task text, priorities, no `live` badge |
| Synthesized fallback | Always / when no todos exist | Agent goals or last known action, green `live` badge |

Both sources are per-project — switching between repos in different terminal tabs never mixes their boards.

### Tips for good `label`s

`step.label` shows up next to each numbered arrow and in the Steps pane — write it like a log line, not prose:

- ✅ `POST /v1/invites { email, role } → 201 { inviteId }`
- ✅ `publish event "user.invited" to SNS`
- ✅ `useInviteUser() → graphql mutation inviteUser($input)`
- ❌ `Sends a request to the API` (too vague)
- ❌ `The web app does some processing and then talks to the auth service` (narrative)

`step.detail` is the prose line underneath in the Steps pane — one sentence on what changes, where the code lives, or a non-obvious side-effect.

### What if Chrome doesn't auto-open?

Within a single session, the hook only opens Chrome once (then no-ops for ~8 hours per-cwd) so it doesn't steal focus on every prompt. To force-open at any time:

```bash
open "file://$HOME/.claude/workflow-docs/index.html"          # macOS
xdg-open "file://$HOME/.claude/workflow-docs/index.html"      # Linux
```

The rendered HTML is rebuilt in place on every prompt — just reload the tab to pick up changes.

---

## Schema cheatsheet

```jsonc
{
  "app":        { "name": "...", "description": "..." },
  "categories": [{ "id": "actor", "label": "Actor", "color": "#f472b6" }],
  "columns":    [{ "id": "actors", "label": "ACTORS" }],
  "components": [
    { "id": "web-app", "name": "web-app frontend", "subtitle": "React + Pulsate dashboard",
      "column": "client", "category": "client" }
  ],
  "flows": [{
    "id": "invite-new-user",
    "name": "Invite a new user",
    "description": "Org admin opens InviteUserForm in the dashboard",
    "category": "User management",
    "steps": [{
      "from":   "admin-browser",
      "to":     "web-app",
      "label":  "submit invite form",
      "detail": "InviteUserForm.tsx posts { email, role } to the createInvite cloud function."
    }]
  }]
}
```

Suggested column spine (left-to-right, request-flow direction):

```
Actors → Client surfaces → Backend/functions → Storage/data → Pipeline → Distribution → External services
```

Suggested category palette:

| `id`             | colour   |
| ---------------- | -------- |
| `actor`          | pink `#f472b6` |
| `client`         | cyan `#22d3ee` |
| `firebase-fn`    | violet `#a78bfa` |
| `firebase-data`  | orange `#fb923c` |
| `pipeline`       | green `#34d399` |
| `distribution`   | blue `#60a5fa` |
| `external`       | gray `#9ca3af` |

Full example in [`example-flows.json`](./example-flows.json).

### Backwards compatibility

The renderer also accepts an older `packages` schema with `label`/`annotation`/`payload` fields and converts it at load time. New files should be written in the canonical schema above.

### Validation rules

- Every `step.from` / `step.to` must reference an existing `components[].id`
- Every `component.column` must reference an existing `columns[].id`
- Every `component.category` must reference an existing `categories[].id`
- `id` is unique within `categories[]`, `columns[]`, `components[]`, and `flows[]`
- `categories`, `columns`, `components`, `flows`, and per-flow `steps` are non-empty

---

## Source resolution order

The hook looks for `flows.json` in this order — first one wins:

1. `$PWD/flows.json` — in the repo, shared with the team
2. `$PWD/.claude/flows.json` — usually gitignored, project-local
3. `$PWD/docs/flows.json` — alongside other project docs
4. `~/.claude/workflow-docs/projects/<project-slug>/flows.json` — **per-project sandbox under `~/.claude`** (zero project pollution; auto-created on first session). Slug is `<basename(PWD)>-<8-char-hash>` so `~/.claude/workflow-docs/projects/` stays human-scannable (e.g. `my-app-a1b2c3d4/`).
5. `~/.claude/workflow-docs/flows.json` — global fallback
6. Falls back to the bundled `example-flows.json`

### Auto-bootstrap on first session

The first time you open Claude Code in a new project (no `flows.json` exists in paths 1–4), the `bootstrap-flows.sh` hook:

- Creates `~/.claude/workflow-docs/projects/<project-slug>/flows.json` seeded with the example.
- Drops a `.needs-generation` marker next to it.
- Injects a `SessionStart` context message telling Claude to invoke the `workflow-doc-generator` subagent and replace the placeholder with your project's actual architecture.

The file lives entirely under `~/.claude` — your repo stays clean. Want to share the diagram with your team? Move it to `$PWD/flows.json` (the renderer will pick it up via path 1 on the next session). The subagent removes the marker after the first generation so you only get nudged once per project.

### Architecture summary on every session (Claude memory)

After the first session bootstrap, every subsequent session in the project triggers a second behaviour from the same hook: it reads `flows.json` and emits a compact summary of the architecture as `SessionStart.additionalContext`. Claude sees the project's components and flows from turn 0 — no need to ask it to "read the flows file first" before architecture-shaped questions.

The summary contains:

| Section | Contents |
| --- | --- |
| Header | App name + description, live-view URL |
| Lanes | Left-to-right spine (`Actors → Client surfaces → …`) |
| Categories | The colour-coded legend (`Actor`, `Client surface`, …) |
| Components | `name [column / category] — subtitle` for each, capped at 50 |
| Flows | `name (N steps) — description` for each, capped at 20 |

Typical payload is **500–1500 tokens** per session. If you don't want this, delete `~/.claude/hooks/bootstrap-flows.sh` and the matching `SessionStart` entry from `~/.claude/settings.json`.

---

## Turn it off

Easiest: rename or delete `~/.claude/hooks/open-workflow-docs.sh` — the hook silently no-ops. Or remove the `SessionStart` and `UserPromptSubmit` entries from `~/.claude/settings.json`.

---

## Skills in this kit

| Skill | What it does |
|---|---|
| `workflow-visualizer` | Owns the `flows.json` schema, the `template.html` renderer, and the canonical `PROMPT.md` spec. Use when creating or editing the architecture diagram. |
| `workflow-kanban-task` | Plain-English task management for the Kanban board. Add, move, complete, list, and remove tasks. Writes `tasks.json` which the board polls every 1 s. |

The `workflow-doc-generator` subagent wraps `workflow-visualizer` for whole-project documentation generation.

## Files in this folder

- [`PROMPT.md`](./PROMPT.md) — **canonical spec.** The source-of-truth instructions an AI must follow to generate the diagram. Paste it into any LLM chat as the system prompt and you'll get the same look.
- `install.sh` — installer (merges into existing `settings.json`)
- `settings.json` — hook fragment merged by the installer
- `open-workflow-docs.sh` — the hook script
- `workflow-doc-generator.md` — the subagent definition
- `SKILL.md` — the skill (schema + rendering contract)
- `template.html` — the single-file viewer
- `example-flows.json` — ToDesktop reference dataset
- `claude-workflow-docs.tar.gz` — same files in the nested layout `install.sh` expects
- [`INSTALL.md`](./INSTALL.md) — automated + manual install steps
