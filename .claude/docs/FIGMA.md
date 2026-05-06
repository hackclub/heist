> **Load when**: implementing a Figma URL or `get_design_context` output into ERB.
> **Skip when**: small CSS tweaks, copy edits, or non-visual work. See [Small fix mode](../../AGENTS.md#small-fix-mode).

# Implementing Figma Designs Correctly

This guide is about doing Figma implementation right. The Figma MCP server gives you context and a screenshot; getting from that to production code without drift is the work. These rules keep implementations faithful to the design, consistent with the rest of the app, and reviewable.

If your task is purely backend, you do not need this guide. If you are writing back into Figma (creating nodes, variables, components), use the `figma-use` or `figma-generate-design` skills.

## Scope before starting

Before any tool calls or code:

1. **Categorize the work.** A "Figma implementation" hides one of three kinds of change. Decide which before anything else:

   - **Pure visual.** Restyling existing functionality. No new routes, model attributes, controller logic, or client behavior. Stay within this doc and [HOTWIRE.md](./HOTWIRE.md).
   - **Visual + new client behavior.** Adds Stimulus controllers, interactions, animations, or hover/focus states the codebase does not yet have. No backend changes. Pull in [HOTWIRE.md](./HOTWIRE.md).
   - **Visual + feature work.** The design implies functionality that does not exist yet: a button with no endpoint behind it, a count with no model column, an admin badge with no policy, a list with no controller fetch. The Figma slice is one part of a larger feature; the [New Feature Checklist in AGENTS.md](../../AGENTS.md#new-feature-checklist) also applies, and so do [RAILS.md](./RAILS.md), [DATABASE.md](./DATABASE.md), and [AUTH.md](./AUTH.md) as relevant.

   To decide, look at both the design context AND the screenshot, then ask yourself:

   - Does the design imply **state** that doesn't exist on the model? (favorites, drafts, statuses, counts, "last updated", "is admin", etc.)
   - Does the design imply a **route or action** that doesn't exist? (a button without an endpoint, a form without a controller)
   - Does the design imply **data** the controller does not currently fetch?
   - Does the design imply a **permission distinction**? (admin-only chrome, owner-only edits, signed-in vs anonymous variants)
   - Does the design imply **external service** behavior? (a Hackatime stat, a YouTube embed, a Ferret search result)

   If any answer is yes, this is **visual + feature work**. Surface it to the user *before* writing visual code:

   > "This implementation also requires: a `favorites` join table, a `Favorites::Create` action gated by `FavoritePolicy`, and an `includes(:favorites)` on the home query. Do you want me to do all of it as one PR, split into a UI-only PR plus a feature PR, or stub the visual as 'not wired yet' for now?"

   Do not silently build feature plumbing. Do not silently skip it either, leaving a button that 404s.

2. **Confirm what the user named.** "Implement the hero section" is not "implement the landing page." If the user named a section, component, or node, implement only that.
3. **List sibling sections you will NOT touch.** State them back to the user. This makes scope creep impossible to do silently.
4. **Ask if scope is ambiguous.** A Figma URL with no `nodeId` is ambiguous. A frame containing four sections is ambiguous. Ask which section, do not guess.
5. **Match Heist scope discipline.** See [Scope discipline](../../AGENTS.md#scope-discipline). The named section is the contract; everything else is out of scope.

If the named section depends on a sibling (shared partial, parent layout, design token, missing model attribute), surface it before starting. Do not silently expand scope to include the dependency.

## Mindset

- **The screenshot is the spec.** The JSON from `get_design_context` describes intent; the screenshot is what the designer signed off on. They must agree. When they disagree, the screenshot wins and you flag the discrepancy.
- **Pixel-perfect is the bar.** "Close enough" is not the bar. If something is off by 4px, it is wrong. Fix it or explain why you cannot.
- **Do not eyeball values.** Spacing, font size, color, radius, line height all come from the design context or the project's tokens. Never from your own visual estimate.
- **Reuse before you build.** Almost every design uses primitives this codebase already has. Grep before creating a new partial (step 0).
- **Translate, do not transcribe.** The MCP output is React + Tailwind. The codebase is ERB + Hotwire. You are translating, not pasting.

## Required workflow

Every Figma implementation goes through these steps in order. Skipping a step is how implementations drift.

### 0. Grep for existing partials and controllers

Before you assume you need a new partial, run:

```sh
rg -l "<%= render" app/views/shared/ app/views/<feature>/
rg -l "data-controller=\"<likely-controller-name>\"" app/javascript/controllers/ app/views/
```

If anything looks close, read it. If nothing matches, say so explicitly in your response before creating a new partial.

### 1. Get the design context

Ask the user for the Figma URL or confirm a node is selected in the desktop app. Do not invent or guess a `fileKey` or `nodeId`. Once you have them, call:

```
get_design_context(fileKey, nodeId)
```

If the response is truncated, call `get_metadata` first, identify the child node IDs you actually need, and pull each child individually. Do not implement from a truncated payload.

### 2. Get the screenshot

```
get_screenshot(fileKey, nodeId)
```

Keep it open. Every per-section check compares against this image.

### 3. Resolve tokens before writing code

For each color, spacing value, and font size in the design context:

1. Check the existing palette and Tailwind config for a matching token.
2. If a token exists, use it. If not, stop and decide: ask before adding a new token, or pick the closest existing one and document why.

You should know every value you are about to write into a template before you write it.

**Landing page palette.** The authoritative palette lives in your project memory at `project_landing_palette.md` and is exposed as CSS variables in `app/views/landing/index.html.erb`:

| Hex       | CSS var               | Role                                    |
|-----------|-----------------------|-----------------------------------------|
| `#C0F476` | `--heist-lime`        | Primary CRT lime                        |
| `#DAFBAC` | `--heist-lime-soft`   | Soft lime body text, hints, borders     |
| `#DEC35F` | `--heist-amber`       | Mustard gold (LOG IN, JOIN, STREAM)     |
| `#FFE572` | `--heist-yellow`      | Bright yellow highlight                 |
| `#14251C` | `--heist-ink`         | Dark ink for text on amber/yellow       |

Use the CSS variable, not a raw hex. If you write a different hex on the landing page, you are wrong.

**Hard rule.** Writing `bg-[#`, `text-[#`, `border-[#`, or any other arbitrary hex utility in a template is a task failure. Use a Tailwind token or a CSS variable. If neither exists for a needed color, stop and ask.

### 4. Implement one section at a time

Implement the smallest meaningful chunk (one section, one component). After each chunk, run the per-section check below. Do not implement the whole page and validate at the end; differences compound and become hard to attribute.

#### Per-section check (run after every chunk)

- [ ] Compare against the screenshot. Layout, spacing, typography, color match.
- [ ] No raw hex literals introduced.
- [ ] No inline `<script>` or `onclick=` attributes introduced.
- [ ] Hover, active, focus, disabled states implemented if the design specifies them.
- [ ] Any new partial was preceded by a grep showing nothing existing matches.

If any check fails, fix before moving to the next chunk.

### 5. Final validation

Before you report the task complete, run the final checklist at the bottom of this doc.

## Fidelity rules

### Layout

- Use the spacing values from the design context, mapped to Tailwind utilities (`p-4`, `gap-6`, etc.). If a value does not have a clean utility, use the closest token rather than an arbitrary `[24px]`.
- Auto Layout in Figma maps to Flex or Grid. Match the direction, alignment, and gap exactly.
- Do not collapse or merge nested frames "for cleanliness." The structure is part of the design.

### Typography

- Font family, size, weight, and line height come from the design context. All four must match.
- If the project does not have a font weight Figma is using, ask before substituting.
- Letter spacing matters at display sizes. Do not silently drop it.

### Color

- Colors come from palette tokens and CSS variables, not raw hex.
- If Figma names a color that is not in the token set, do not invent a `bg-[#hex]` utility. Add it to the config or ask.
- Preserve opacity layers (`bg-black/40`) exactly. Do not approximate them by darkening the underlying color.

### Imagery and icons

- Download assets from the Figma MCP `localhost` URLs into `app/assets/images/<feature>/`. Use those paths in templates.
- Do not add a new icon library because Figma used one. Inline the SVG or export from Figma.
- Do not use placeholders if an asset URL was provided.

### Interaction and motion

- Implement only the interaction states the design specifies. Do not invent states.
- Promote every interaction to a Stimulus controller. No inline `<script>`. No `onclick=`. See [HOTWIRE.md](./HOTWIRE.md).
- Animations from Figma prototypes must respect `prefers-reduced-motion`.

### Responsive

- Match Figma constraints to Tailwind breakpoints (`sm:`, `md:`, `lg:`, `xl:`). If Figma has only one frame, ask which breakpoints matter rather than guessing.
- Test the breakpoints in the browser, not just in the Figma frame.

## Translation rules

The MCP output is a representation, not the implementation. Apply these translations.

| Figma output                              | Heist implementation                                              |
|-------------------------------------------|-------------------------------------------------------------------|
| React component                           | ERB partial under `app/views/<feature>/` or `app/views/shared/`   |
| `useState`, `onClick`, JSX event handlers | Stimulus controller, `data-controller`, `data-action`             |
| Inline SVG icon                           | `image_tag` from `app/assets/images/` or inline `<svg>`           |
| Hard-coded hex values                     | Tailwind tokens or CSS variables                                  |
| CSS-in-JS / styled props                  | Tailwind utilities, or `class_names` helper for conditionals      |
| `<button onClick=...>`                    | `<button data-action="click->controller#method">`                 |

If the React snippet has logic, that logic moves into a Stimulus controller. The ERB stays declarative.

### Worked example

Figma MCP returned:

```jsx
<button
  className="bg-[#DEC35F] text-[#14251C] px-6 py-3 rounded font-bold hover:bg-[#FFE572]"
  onClick={handleJoin}
>
  JOIN
</button>
```

Wrong (transcribed):

```erb
<button class="bg-[#DEC35F] text-[#14251C] px-6 py-3 rounded font-bold hover:bg-[#FFE572]" onclick="handleJoin()">
  JOIN
</button>
```

Right (translated):

```erb
<%= button_tag class: "bg-heist-amber text-heist-ink px-6 py-3 rounded font-bold hover:bg-heist-yellow",
               data: { action: "click->signup#join" } do %>
  JOIN
<% end %>
```

Hex values resolved to palette tokens. The handler became a Stimulus action. The element is still semantically a button.

## Final validation checklist

Run before reporting done. Compare against the screenshot from step 2.

- [ ] Only the named section was implemented. Sibling sections untouched.
- [ ] Layout, typography, and color match section by section.
- [ ] No raw hex utilities anywhere in the diff.
- [ ] Interaction states match the design (no extras invented).
- [ ] Responsive behavior matches Figma constraints at every breakpoint.
- [ ] Assets render from `app/assets/images/`, not external CDNs or placeholders.
- [ ] Accessibility: semantic roles, labels, keyboard navigation, focus visible.
- [ ] `prefers-reduced-motion` honored for any animation.
- [ ] No inline `<script>` and no inline event handlers.
- [ ] No new partial duplicates an existing one (grep documented).
- [ ] `bin/rubocop -f github` passes.
- [ ] Page rendered in the browser signed-out and signed-in.

If any item fails, fix it before reporting done. Do not list known visual differences as "follow-up."

## Reporting honestly

When you report a Figma implementation as complete:

- State the node ID and the section name you implemented.
- List the sibling sections you did NOT touch (proves scope discipline).
- Call out any deviation from the design with the reason.
- If you could not match something, say so explicitly. Do not pretend it matches.

Underclaiming is fine. Overclaiming gets caught at review and erodes trust.

## Common ways implementations drift

1. **Hard-coded hex values** instead of palette tokens.
2. **Eyeballed spacing.** `p-3` vs `p-4` is visible. Use the design-context value.
3. **Missing interaction states.** The default state matches; hover does not.
4. **Pasting React JSX into ERB.** Inline `onClick` handlers slip through and break the no-inline-JS rule.
5. **New partial that duplicates an existing one.** Always grep first.
6. **Skipping `prefers-reduced-motion`.** A Figma prototype animation in production is an accessibility regression.
7. **Validating once at the end.** Compounded differences are hard to attribute.
8. **Truncated `get_design_context` payload.** Implementing from partial data produces partial work.
9. **Implementing sibling sections you weren't asked for.** The named section is the contract.
10. **Implementing visuals while the feature plumbing is missing.** A button with no endpoint behind it, a count with no column, a badge with no policy. Categorize the work in step 1 and surface missing plumbing before touching ERB.

## Related

- [HOTWIRE.md](./HOTWIRE.md) — Stimulus, Turbo, Tailwind, accessibility
- [LESSONS.md](./LESSONS.md) — recorded agent-failure patterns
- [Scope discipline](../../AGENTS.md#scope-discipline) — project-wide scope rules