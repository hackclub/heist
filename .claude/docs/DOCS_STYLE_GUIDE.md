# Documentation Style Guide

This guide applies to Markdown documentation in `docs/`, served at `/docs` via `MarkdownController`. It does not apply to `README.md`, `AGENTS.md`, or files under `.claude/docs/`.

## Research Before Writing

Before documenting a feature:

1. **Research similar documentation** — read existing pages under `docs/` to understand conventions.
2. **Read the code** — controllers, models, policies, service objects.
3. **Verify the Pundit policy** — know which roles can access the feature and under what scope.
4. **Check UI thresholds and defaults** — review the view, Stimulus controllers, and any model defaults.
5. **Cross-reference tests** — `test/` documents expected behavior and edge cases.
6. **Confirm routes** — run `bin/rails routes -g <pattern>` to get the real URL.

### Code verification checklist

- Read the controller action in `app/controllers/`.
- Check the policy in `app/policies/`.
- Review the view in `app/views/` and any Stimulus controller in `app/javascript/controllers/`.
- Verify defaults (booleans, enums) in the model.
- Confirm route paths in `config/routes.rb`.
- Check env vars referenced in `config/initializers/` or services.

## Document Structure

### Title and introduction

**H1 heading**: single clear title, no prefix.

```markdown
# Ship Review Workflow
```

**Introduction**: 1-2 sentences describing what the feature does.

```markdown
Ships are submissions of a Project for review. Admins can approve, return, or reject them, and the submission data is frozen at the time of review.
```

### Overview section

After the intro, a short Overview section listing the main capabilities:

```markdown
## Overview

The Ship Review Workflow supports:

- **Submit**: A user submits a Project and creates a Ship record.
- **Review**: Admins mark the Ship approved, returned, or rejected.
- **Freeze**: Approved Ships snapshot the Project data at approval time.
```

Use bold labels for capabilities.

## Image Usage

### Placement and format

Place images after the descriptive text, then a caption:

```markdown
![Ship review queue](../images/admin/ship-queue.png)

<small>Admin view of the Ship review queue showing pending submissions.</small>
```

- Alt text: describe what's shown. Don't repeat the heading.
- Caption: `<small>` below the image.
- Path: relative to the markdown file.

### Image-driven documentation

When you have multiple screenshots:

1. Structure sections around images.
2. Describe what's visible; reference specific UI elements by name.
3. Let screenshots guide the reader through the feature.

## Content Organization

### Section hierarchy

1. **H2 (`##`)**: major sections — Overview, Access, Permissions, Use Cases.
2. **H3 (`###`)**: subsections.
3. **H4 (`####`)**: rare.

### Common sections

- **Accessing [Feature]**: how to get there.
- **Permissions**: which roles can do what, mapped to Pundit policy rules.
- **Use Cases**: practical applications.
- **Related Documentation**: links at the end.

### Lists and callouts

- Unordered lists for non-sequential items.
- Ordered lists for steps.
- Tables for comparing options or listing permissions.
- `> [!NOTE]`, `> [!WARNING]`, `> [!TIP]` for callouts.

## Writing Style

### Tone and voice

- **Direct and concise.** Cut unnecessary words.
- **Active voice**: "Admins approve Ships" not "Ships are approved."
- **Present tense**: "The queue displays..." not "The queue will display...".
- **Second person**: "You can view..." for instructions.

### Terminology

- Consistent terms. Use "Ship" throughout, not a mix of "ship", "submission", and "project submission".
- **Bold for UI elements**: "Click **Approve**."
- `Code formatting` for commands, paths, parameter names.

### Punctuation

- **No emdash** (`—`), **no endash** (`–`), no ` -- `. Use commas, semicolons, or periods. Restructure if needed. For numeric ranges, use a plain hyphen (`0-100`).

### Instructions

- Numbered lists for sequential steps.
- Start with a verb: Navigate, Click, Select, Run.
- Use the exact button/menu text, bolded.

## Code Examples

### Commands

````markdown
```sh
bin/rails runner 'Ship.pending.count'
```
````

### Ruby

````markdown
```ruby
class ShipPolicy < ApplicationPolicy
  def approve?
    admin?
  end
end
```
````

### Environment variables

````markdown
```sh
HACKATIME_CLIENT_ID=...
HACKATIME_CLIENT_SECRET=...
```
````

Keep examples minimal. Show only what the reader needs.

## Links and References

### Internal links

Use relative paths:

- `[Ship Policy](./ship-policy.md)`
- `[Admin Guide](../admin/index.md)`

### External links

Link the full URL, not `[click here]`:

- Good: `See the [Rails routing guide](https://guides.rubyonrails.org/routing.html)`
- Bad: `[Click here](https://guides.rubyonrails.org/routing.html)`

### API/route references

Use full paths:

```markdown
`GET /projects/:id` — shows a project
`POST /admin/reviews/:id` — updates a Ship's status
```

## Accuracy Standards

### Specific numbers matter

Document exact values from code:

- **Pagy default**: 20 items per page.
- **Rate limits** from Rack::Attack.
- **TTLs** from `Rails.cache.fetch` calls.

### Permission details

- Use exact policy method names (`ShipPolicy#approve?`).
- Specify which roles can perform each action.
- Reference the scope for index actions.

### Route accuracy

- Use full paths, not shorthand.
- Link to `bin/rails routes` output if it clarifies.

## Formatting and Linting

Before merging documentation:

1. Preview in dev: visit `/docs` locally.
2. Run `bin/rubocop -f github` (it covers YAML frontmatter if present).
3. Verify all links resolve.

## Formatting Conventions

- **Bold** (`**text**`) — UI elements, important concepts.
- *Italic* (`*text*`) — emphasis, rare.
- `Code` — commands, paths, parameter names.

### Tables

- Compare options, list parameters, show permissions.
- Left-align text, right-align numbers.
- Keep simple. Avoid nested formatting.

### Code blocks

- Always specify the language.
- Keep minimal — show only what's relevant.

## Document Length

- Comprehensive but scannable.
- Break long sections with H3 subheadings.
- Use images and code blocks to break up text.

## Key Principles

1. **Research first** — verify against the actual code.
2. **Be precise** — exact route paths, policy names, env vars.
3. **Visual structure** — headings, tables, lists.
4. **Link everything** — related docs, routes, source files.
5. **Active, present, second-person.**
6. **No emdash.**
