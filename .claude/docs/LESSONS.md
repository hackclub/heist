> **Load when**: starting non-trivial work, especially anything Figma, frontend, or scope-sensitive. Skim before you begin.
> **Skip when**: a one-line fix where context is obvious.

# Lessons (Recorded Agent Failures)

This is the project's living memory of how an agent has gone wrong on Heist. Each entry is something a previous Claude (or a previous human) actually shipped or almost shipped. The pattern matters more than the specific incident.

When a new failure pattern is caught, append a new entry. Format:

```markdown
## NN. <Short title>

**Symptom.** What the wrong output looked like.
**Why it's wrong.** The rule it broke and the consequence.
**Right behavior.** What should have happened instead.
**Heuristic.** A short rule of thumb for next time.
```

Keep entries short. Two to four sentences each section. Do not turn this into a doc; it is an index of mistakes, not a tutorial.

---

## 01. Eyeballed landing-page palette

**Symptom.** Picked `#D39F3B` for the amber button because it looked close to the Figma. Picked `#C5F187` for the lime. Both wrong by ~10% saturation.
**Why it's wrong.** The landing page has an authoritative palette pinned to a Figma frame. Eyeballed shades drift on every iteration and create rework when the user notices.
**Right behavior.** Read `project_landing_palette.md` (in user memory). Use the CSS variable defined in `app/views/landing/index.html.erb`. The five values are `#C0F476` (lime), `#DAFBAC` (lime-soft), `#DEC35F` (amber), `#FFE572` (yellow), `#14251C` (ink).
**Heuristic.** If the file is under `app/views/landing/`, the palette is fixed. Use the variable. Never write a hex.

## 02. Raw hex utilities in a template

**Symptom.** Wrote `class="bg-[#DEC35F]"` directly in ERB after copy-pasting from Figma's MCP output.
**Why it's wrong.** Tokens exist for a reason. A raw hex looks right today and breaks the moment a design token changes. It also defeats the palette rule above.
**Right behavior.** Resolve to a Tailwind token (`bg-heist-amber`) or a CSS variable. If neither exists, stop and ask before adding a new one.
**Heuristic.** `bg-[#`, `text-[#`, `border-[#` in a diff is a task failure. Search for it before reporting done.

## 03. Implemented sibling Figma sections that weren't asked for

**Symptom.** Asked to implement the hero section. Also implemented the FAQ and footer because they were in the same Figma frame.
**Why it's wrong.** Scope creep. The user can't review work they didn't ask for. It also wastes the user's time and tokens.
**Right behavior.** Implement only what was named. Before starting, list back the section name AND the sibling sections you will not touch. If unsure which section was meant, ask.
**Heuristic.** "Implement the hero" is a contract. Treat the Figma URL as a frame of reference, not a work order for everything in it.

## 04. Pasted JSX `onClick` into ERB

**Symptom.** Figma MCP returned `<button onClick={handleX}>`, and the ERB ended up with `<button onclick="handleX()">`.
**Why it's wrong.** Inline JS handlers are banned. They bypass Stimulus, are not testable, and break CSP if it ever ships.
**Right behavior.** Promote the handler to a Stimulus controller. Use `data-action="click->controller#method"`. The translation table in [FIGMA.md](./FIGMA.md) covers this.
**Heuristic.** If the diff contains `onclick=`, `onsubmit=`, or `<script>`, the diff is wrong.

## 05. Promoted `# typed:` levels in unrelated files

**Symptom.** The task was a one-line copy fix in a controller. Diff also added `# typed: true` and a handful of `sig` blocks to the same file.
**Why it's wrong.** Promoting strictness is a separate decision from fixing copy. It changes the file's failure surface and forces unrelated review.
**Right behavior.** Touch only what the task names. The "Replace these patterns" table in [RAILS.md](./RAILS.md) is a target state, not a license to refactor.
**Heuristic.** Did the user ask you to promote types? If no, don't.

## 06. Introduced a service object for one caller

**Symptom.** Asked to fix a small bug in a controller action. Diff extracted the action's logic into a new `app/services/foo_service.rb` "for testability."
**Why it's wrong.** New abstractions for one caller add review burden, type surface, and indirection. They almost never get reused as imagined.
**Right behavior.** Inline the fix. If the user later adds a second caller, they can extract then.
**Heuristic.** One caller, no service object. Two callers, maybe. Three, probably.

## 07. Forgot `bundle exec tapioca dsl` after a model change

**Symptom.** Added a scope and an enum to a model. CI failed on `tapioca dsl --verify` because the regenerated RBI was not committed.
**Why it's wrong.** DSL RBIs reflect the model's surface. Drift between code and RBI breaks `srb tc` and is the #1 cause of CI failure on a typed Rails project.
**Right behavior.** After any model / association / enum / scope / job change, run `bundle exec tapioca dsl` and commit the updated `sorbet/rbi/dsl/*.rbi` files.
**Heuristic.** Touched a model? Run tapioca dsl before opening the PR.

## 08. N+1 from a Turbo Frame fetch

**Symptom.** The home Partners-in-Crime feed loaded fine in development. In production logs, every Turbo Frame request hit `users` and `projects` lookups separately for one ship.
**Why it's wrong.** A Turbo Frame fetch re-runs the index query for one record. Without `includes`, every render re-fetches associations.
**Right behavior.** Add `.includes(:user, :project)` to the scoped query in the controller. Verify by tailing the dev log and confirming no per-record `SELECT`s.
**Heuristic.** Any view that iterates records and reads associations needs `includes`. Turbo Frames are not exempt.

## 09. Skipped `prefers-reduced-motion` on a Figma prototype animation

**Symptom.** Implemented a hover scale animation directly from a Figma prototype. No media query.
**Why it's wrong.** Users who set `prefers-reduced-motion: reduce` get the animation anyway. Accessibility regression.
**Right behavior.** Wrap the animation in a `@media (prefers-reduced-motion: no-preference)` block, or use Tailwind's `motion-safe:` prefix.
**Heuristic.** If the design specifies motion, write the reduced-motion fallback in the same diff.

## 10. Validated Figma fidelity once at the end

**Symptom.** Implemented an entire landing section, then compared against the screenshot. Found six small differences and could not attribute which change caused which.
**Why it's wrong.** Differences compound. The fix order is unclear and you end up shotgunning corrections.
**Right behavior.** Validate per chunk. After each section or component, do the per-section check in [FIGMA.md](./FIGMA.md) before moving on.
**Heuristic.** Implement one chunk. Compare. Then the next.

## 11. Created a duplicate partial without grepping

**Symptom.** Created `app/views/landing/_card.html.erb` for a card that was already implemented as `app/views/shared/_card.html.erb`.
**Why it's wrong.** Two partials drift over time. Future style changes have to be made twice and one will be missed.
**Right behavior.** Run `rg -l "<%= render" app/views/shared/ app/views/<feature>/` before creating any partial. State the grep result in your response. Reuse if anything looks close.
**Heuristic.** Never create a partial without saying "I grepped and nothing matches because X."

---

## How to add a new lesson

1. Catch a failure (yours or a previous agent's). Note the symptom in concrete terms.
2. Append an entry using the template at the top.
3. Keep it short. Two to four sentences per section.
4. Do not turn this into a tutorial. The point is the failure pattern, not the fix mechanics. Link to topical docs for those.