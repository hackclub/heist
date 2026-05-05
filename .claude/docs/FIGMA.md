# Implementing Figma Designs Correctly

This guide is about doing Figma implementation **right**. The Figma MCP server can give you context and a screenshot; getting from that to production code without drift is the work. This doc captures the rules that keep an implementation faithful to the design, consistent with the rest of the app, and reviewable.

If your task is purely backend, you do not need this guide. If you are writing back into Figma (creating nodes, variables, components), use the `figma-use` or `figma-generate-design` skills, not this doc.

## Mindset

Before you write a single line of ERB:

- **The screenshot is the spec.** The JSON from `get_design_context` describes intent; the screenshot is what the designer signed off on. They must agree. When they disagree, the screenshot wins for visuals and you flag the discrepancy.
- **Pixel-perfect is the bar.** "Close enough" is not the bar. If something is off by 4px, it is wrong. Fix it or explain why you cannot.
- **Do not eyeball values.** Spacing, font size, color, radius, line height all come from the design context or the project's tokens. Never from your own visual estimate.
- **Reuse before you build.** Almost every design uses primitives this codebase already has. Search `app/views/shared/` and the sibling view directory before creating a partial.
- **Translate, do not transcribe.** The MCP output is React + Tailwind. The codebase is ERB + Hotwire. You are translating, not pasting.

## Required workflow

Every Figma implementation goes through these steps in order. Skipping a step is how implementations drift.

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

Keep it open while you work. Every validation pass compares against this image.

### 3. Resolve tokens before writing code

For each color, spacing value, and font size in the design context:

1. Check the existing landing palette and Tailwind config for a matching token.
2. If a token exists, use it. If not, **stop** and decide: ask before adding a new token, or pick the closest existing one and document why.

You should know every value you are about to write into a template before you write it.

### 4. Implement, then validate, then iterate

Implement one section at a time. After each section, compare against the screenshot. Do not implement the whole page and validate at the end; differences compound and become hard to attribute.

### 5. Final validation

Before you mark the task complete, run the validation checklist below.

## Fidelity rules

These are the rules that keep the implementation faithful to the design.

### Layout

- Use the spacing values from the design context, mapped to Tailwind utilities (`p-4`, `gap-6`, etc.). If a value does not have a clean utility, use the closest token rather than an arbitrary `[24px]`.
- Auto Layout in Figma maps to Flex or Grid. Match the direction, alignment, and gap exactly.
- Do not collapse or merge nested frames "for cleanliness." The structure is part of the design.

### Typography

- Font family, size, weight, and line height come from the design context. All four must match.
- If the project does not have a font weight Figma is using, ask before substituting.
- Letter spacing matters at display sizes. Do not silently drop it.

### Color

- Colors come from palette tokens, not raw hex.
- If Figma names a color that is not in the token set, do not invent a `bg-[#hex]` utility. Add it to the config or ask.
- Preserve opacity layers (`bg-black/40`) exactly. Do not approximate them by darkening the underlying color.

### Imagery and icons

- Download assets from the Figma MCP `localhost` URLs into `app/assets/images/<feature>/`. Use those paths in templates.
- Do not add a new icon library because Figma used one. Inline the SVG or export from Figma.
- Do not use placeholders if an asset URL was provided.

### Interaction and motion

- Hover, active, focus, and disabled states must all be implemented, not just the default state. The design context lists them; the screenshot may not show them.
- Promote every interaction to a Stimulus controller. No inline `<script>`. No `onclick=`. See [HOTWIRE.md](./HOTWIRE.md).
- Animations from Figma prototypes must respect `prefers-reduced-motion`. Wrap motion in a media query or skip it for users who opt out.

### Responsive

- Match Figma constraints to Tailwind breakpoints (`sm:`, `md:`, `lg:`, `xl:`). If Figma has only one frame, ask which breakpoints matter rather than guessing.
- Test the breakpoints in the browser, not just in the Figma frame.

## Translation rules

The MCP output is a representation, not the implementation. Apply these translations.

| Figma output | Heist implementation |
|---|---|
| React component | ERB partial under `app/views/<feature>/` or `app/views/shared/` |
| `useState`, `onClick`, JSX event handlers | Stimulus controller, `data-controller`, `data-action` |
| Inline SVG icon | `image_tag` from `app/assets/images/` or inline `<svg>` in the partial |
| Hard-coded hex values | Tailwind tokens defined in the project config |
| CSS-in-JS / styled props | Tailwind utilities, or `class_names` helper for conditionals |
| `<button onClick=...>` | `<button data-action="click->controller#method">` |

If the React snippet has logic, that logic moves into a Stimulus controller. The ERB stays declarative.

## Validation checklist

Run this before you report done. Compare the rendered page against the screenshot from step 2.

- [ ] Layout: spacing, alignment, and sizing match.
- [ ] Typography: font, size, weight, and line height match.
- [ ] Color: every color resolves to a palette token and matches the design.
- [ ] Hover, active, focus, and disabled states implemented and correct.
- [ ] Responsive behavior matches Figma constraints at every breakpoint.
- [ ] Assets render from `app/assets/images/`, not external CDNs or placeholders.
- [ ] Accessibility: semantic roles, labels, keyboard navigation, focus visible.
- [ ] `prefers-reduced-motion` honored for any animation.
- [ ] No inline `<script>` and no inline event handlers.
- [ ] No new partial duplicates an existing one.
- [ ] `bin/rubocop -f github` passes.
- [ ] Page rendered in the browser signed-out and signed-in.

If any item fails, fix it before reporting done. Do not list known visual differences as "follow-up."

## Reporting honestly

When you report a Figma implementation as complete:

- State what you compared against (the node ID and the screenshot).
- Call out any deviation from the design with the reason. Examples: "added `prefers-reduced-motion` fallback", "swapped Figma color X for token Y because Z."
- If you could not match something, say so explicitly. Do not pretend it matches.

Underclaiming is fine. Overclaiming gets caught at review and erodes trust.

## Common ways implementations drift

1. **Hard-coded hex values** instead of palette tokens. The implementation looks right today; it breaks the moment a token changes.
2. **Eyeballed spacing.** `p-3` vs `p-4` is a visible difference. Use the value from the design context.
3. **Missing interaction states.** The default state matches; hover does not. The design context lists every state for a reason.
4. **Pasting React JSX into ERB.** Inline `onClick` handlers slip through and break the no-inline-JS rule.
5. **New partial that duplicates an existing one.** Always search `app/views/shared/` first.
6. **Skipping `prefers-reduced-motion`.** A Figma prototype animation in production is an accessibility regression.
7. **Validating once at the end.** Compounded differences are hard to attribute; validate per section.
8. **Truncated `get_design_context` payload.** Implementing from partial data produces an implementation missing parts of the design.

## Related

- [HOTWIRE.md](./HOTWIRE.md) — Stimulus, Turbo, Tailwind, accessibility
- [WORKFLOWS.md](./WORKFLOWS.md) — broader development workflow
- [ARCHITECTURE.md](./ARCHITECTURE.md) — where features live
