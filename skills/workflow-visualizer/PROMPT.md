# PROMPT — Source spec

This is the canonical generation prompt that the `workflow-visualizer` skill and `workflow-doc-generator` subagent follow. When asked to "document the flows" or "build a workflow page" for an app, generate an HTML file that matches **exactly** the layout, look, interaction, and data model below. Do not deviate.

---

```
Create a single-file interactive HTML page documenting the architecture and
workflows of [PROJECT NAME]. It must work offline — no external dependencies,
all data embedded inline.

LAYOUT
- Top: title, one-line subtitle, and a horizontal legend showing a small
  colored dot per component category with its label.
- Main area (~75% width): components laid out in VERTICAL SWIM LANES reading
  left-to-right by tier. Adapt the columns to my system, but the spine should
  be: Actors → Client surfaces → Backend/functions → Storage/data → Pipeline
  → Distribution → External services. Each column has a small uppercase
  letter-spaced header. Each component is a card with its name in a monospace
  font and a small subtitle below.
- Right sidebar (~25% width), split into two stacked panels:
    FLOWS (top): scrollable clickable list, each item shows a bolded name +
    one-line description.
    STEPS (bottom): empty until a flow is selected. Then shows the ordered
    numbered steps for that flow with the from→to route, action label, and
    short detail.

LOOK & FEEL
- Dark navy background, dim card backgrounds with thin borders.
- Each card is tinted/bordered by its category color (matches the legend dot).
- Monospace font (JetBrains Mono or system monospace) for component names —
  gives it a developer-doc feel. UI labels can be sans-serif.
- Gold for accents (step badges, selected state).

INTERACTION
- Click a flow → involved cards stay bright, others dim to ~20% opacity,
  curved bezier SVG arrows render between cards in step order, each with a
  gold circular badge showing the step number at its midpoint, arrowhead at
  the destination end.
- Arrows should route as smooth curves and try to avoid passing through
  unrelated cards. Bidirectional step pairs (A→B and B→A in same flow)
  curve in opposite directions so they don't overlap.
- For self-actions (from === to), put the step badge directly on the card.
- Click the same flow again to clear, or use a "Clear selection" button.
- Redraw arrows on window resize.

DATA MODEL
Drive everything from one inline JSON object in a <script type="application/json">
tag with this shape:

{
  "categories": [{ "id", "label", "color" }],
  "columns":    [{ "id", "label" }],
  "components": [{ "id", "name", "subtitle", "column", "category" }],
  "flows":      [{
    "id", "name", "description",
    "steps": [{ "from", "to", "label", "detail" }]
  }]
}

Include an HTML comment above the JSON documenting the schema so future
editors can add components and flows without reading the JS.

WHAT TO DOCUMENT
[Describe your system here: list every actor, client surface, backend
module, data store, pipeline component, distribution layer, and external
service. Then describe each workflow you want documented as an ordered
list of steps, being specific about what each step passes between
components.]
```

---

## How this fits the rest of the kit

- `template.html` is a working implementation of this spec; the `WHAT TO DOCUMENT` section is filled in at runtime from `flows.json` (the JSON gets embedded into the template's `<script type="application/json" id="flows-data">` tag by the hook).
- `skills/workflow-visualizer/SKILL.md` is the agent-facing version of these rules, with file paths and validation.
- `agents/workflow-doc-generator.md` is the subagent that, given an app, fills in the `WHAT TO DOCUMENT` section by reading the codebase and producing the JSON.

When in doubt, this prompt wins.
