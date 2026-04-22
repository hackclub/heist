# Frontend Development Guidelines (Hotwire + Stimulus + Tailwind)

This project uses server-rendered HTML with Hotwire (Turbo + Stimulus), Tailwind CSS 4, and Importmap. No React, no bundler. The equivalent of a "component library" is ERB partials plus Stimulus controllers.

## Bash commands

- `bin/dev` — start Rails + Tailwind watcher.
- `bin/importmap pin <name>` — add a JS dependency.
- `bin/importmap unpin <name>` — remove it.
- `bin/rails tailwindcss:build` — one-off Tailwind build (usually not needed; `bin/dev` watches).

## Components (ERB partials)

- Partials live alongside the view that uses them: `app/views/projects/_card.html.erb`.
- Shared partials live in `app/views/shared/`.
- **Before creating any new partial, search the codebase** for an existing one. Check `app/views/shared/` and sibling view directories. Duplicating markup creates maintenance burden.
- Keep partials small. If a partial grows past ~100 lines, split it into sub-partials.
- Pass data via `locals:`, not instance variables:

  ```erb
  <%= render "shared/card", title: @project.title, href: project_path(@project) %>
  ```

## Helpers

- View helpers live in `app/helpers/`. Use them for presentation logic that would otherwise repeat across templates.
- Don't put domain logic in helpers. That belongs in the model or a service object.
- Use `tag.*` helpers (`tag.div`, `tag.span`) for programmatic markup. Don't build HTML strings by concatenation.

## Styling (Tailwind CSS 4)

- Tailwind classes directly in ERB templates are the norm.
- Responsive: use Tailwind prefixes (`sm:`, `md:`, `lg:`, `xl:`).
- Group related classes logically: layout → sizing → color → state.
- Prefer Tailwind utilities over custom CSS.
- For brand colors, use the custom tokens defined in `tailwind.config.js` / `application.tailwind.css` (dark green / green / orange heist palette). Don't hand-code hex values in templates.

### Tailwind best practices

- Group related classes.
- Use semantic color tokens where they exist.
- Avoid ad-hoc `bg-[#hex]` values — promote to a theme token if it'll recur.
- Use `class_names` helper or `tag.div class: {...}` for conditional classes:

  ```erb
  <%= tag.div class: class_names("rounded p-4", "bg-green-800" => project.active?) %>
  ```

## Stimulus

- One Stimulus controller per concern. Named by what it does (`dropdown_controller.js`, `stream-embed_controller.js`).
- File path: `app/javascript/controllers/<name>_controller.js`.
- Auto-loaded by the Stimulus Importmap integration. You rarely need to touch `application.js`.
- Configure via `data-*` attributes, not globals.

```html
<div data-controller="dropdown" data-dropdown-open-value="false">
  <button data-action="click->dropdown#toggle">Menu</button>
  <div data-dropdown-target="panel" hidden>…</div>
</div>
```

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]
  static values = { open: Boolean }

  toggle() {
    this.openValue = !this.openValue
    this.panelTarget.hidden = !this.openValue
  }
}
```

### Do

- Keep controllers small. One responsibility each.
- Use `static targets`, `static values`, `static classes` rather than reaching into the DOM.
- Remove event listeners in `disconnect()` if you added them outside Stimulus's action system.

### Don't

- Don't write inline `<script>` in templates.
- Don't write inline event handlers (`onclick=...`).
- Don't reach into the DOM outside the controller's element.
- Don't talk to `window` globals — configure via data attributes.

## Turbo

### Frames

A Turbo Frame isolates a region of the page. A link or form inside a frame scopes its navigation to that frame.

```erb
<%= turbo_frame_tag "project-#{@project.id}" do %>
  <%= render "project", project: @project %>
<% end %>
```

- Frame IDs must be stable and unique on the page.
- Server responses must return a frame with the matching ID, or Turbo falls back to a full-page swap with a warning.

### Streams

Turbo Streams update multiple regions from a single response or a broadcast.

```erb
<%# app/views/ships/create.turbo_stream.erb %>
<%= turbo_stream.prepend "ships", partial: "ships/card", locals: { ship: @ship } %>
<%= turbo_stream.update "flash", partial: "shared/flash" %>
```

Controller:

```ruby
respond_to do |format|
  format.html { redirect_to ships_path }
  format.turbo_stream
end
```

### Broadcasts

For live updates (leaderboard, Partners-in-Crime feed):

```ruby
class Ship < ApplicationRecord
  after_create_commit { broadcast_prepend_to :ships }
end
```

- Broadcasts hit every connected client. Keep the payload small.
- Don't broadcast from inside a long transaction; defer to after-commit.

## Accessibility

- Every `<table>` needs an `aria-label` or `<caption>` so screen readers can distinguish multiple tables on a page.
- Every interactive non-button element with `tabindex="0"` must have a semantic `role` (e.g., `role="button"`).
- When hiding an interactive element visually (opacity, pointer-events-none), **also** remove it from the tab order (`tabindex="-1"`) and accessibility tree (`aria-hidden="true"`), or just don't render it.
- All form inputs need an associated `<label>` (visible or `aria-label`).
- Respect `prefers-reduced-motion` for animations on the stream page.

## Testing frontend behavior

- Use system tests (Capybara + Selenium) for user-visible flows (`test/system/`).
- Assert on **observable behavior** (`assert_text`, `assert_selector`), not on CSS class names.
- Use `data-testid` for elements with no semantic role when needed.
- Don't assert on `opacity-0` or other Tailwind internals. Assert what a user sees.

## Robustness

- When rendering user-facing text from nullable data, provide a **visible fallback** ("Untitled", "N/A", or similar). Never render a blank cell.
- When formatting numbers from external APIs (Hackatime hours), **guard against nil and non-finite values** before formatting.
- Always pass an **explicit locale** to `to_s(:delimited)` or `number_with_delimiter` if you need deterministic output.

## Performance

- Use fragment caching for expensive partials (leaderboard, Partners-in-Crime feed):

  ```erb
  <% cache [ship, :card] do %>
    <%= render "ship_card", ship: ship %>
  <% end %>
  ```

- Invalidate via `touch: true` on associations or explicit cache-key components.
- For high-frequency browser events (scroll, resize) in Stimulus, use `requestAnimationFrame` or throttle.
- Avoid unbounded Turbo Broadcast fan-outs. If thousands of clients watch a stream, broadcast to a shared channel, not per-user.

## Workflow

- Before finishing a frontend change:
  1. `bin/rubocop -f github` passes.
  2. Visit the change in the browser (both signed-out and signed-in).
  3. System test exists for user-visible behavior change.
- Use the browser devtools Network tab to verify Turbo requests return `text/vnd.turbo-stream.html` or a full HTML fragment (not JSON).

## Pre-change checklist

1. Does the change require a new partial, or can I reuse an existing one?
2. Am I using Tailwind utilities, not hand-written CSS?
3. Am I using Stimulus, not inline JS?
4. Is the change accessible (roles, labels, keyboard)?
5. Does the Turbo response target the right frame/stream?
6. Does the server enqueue a broadcast for changes other users should see?
