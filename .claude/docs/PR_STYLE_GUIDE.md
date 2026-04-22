# Pull Request Description Style Guide

## PR Title Format

Format: `type(scope): description`.

- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- Scope must be a real path or directory stem containing every changed file.
- Omit scope for cross-cutting changes (multiple unrelated top-level directories).
- Keep titles under ~70 characters.
- Imperative, present tense.

Examples:

- `feat(app/models): add StreamSegment timing fields`
- `fix(app/policies): prevent discarded projects from appearing in listed scope`
- `perf(app/controllers): includes user and project on ships#index`
- `docs: clarify HCA callback in README`
- `refactor(app/services): extract stream URL building into StreamService`

## PR Description Structure

### Default: keep it concise

Most PRs fit in 1-2 short paragraphs. Focus on **what** and **why**, not implementation detail.

```markdown
[Brief statement of what changed.]

[One sentence explaining the technical rationale or context, if needed.]
```

**Example (bugfix):**

```markdown
Previously, the Partners-in-Crime feed on the home page ran an N+1 query when iterating ships, because `user` and `project` weren't eager-loaded.

Add `.includes(:user, :project)` to the scoped query in `HomeController#index`.
```

**Example (docs correction):**

```markdown
Fixes the HCA callback path in the README. The actual route is `/auth/hca/callback`, not `/auth/callback`.
```

### Complex changes: Summary / Problem / Fix

Use structured sections when the change needs real explanation.

```markdown
## Summary
Brief overview.

## Problem
Detailed explanation of what was broken or missing.

## Fix
How the solution works at a high level.
```

### Large refactors: lead with context

```markdown
This PR rewrites the [component] for [reason].

The previous [component] had [specific issues]: [details].

[What changed]: [specific improvements made].

Refs #[issue-number]
```

## What to Include

### Always include

1. **Linked related work**:
   - `Closes #123`
   - `Refs #456`
   - `Fixes: https://github.com/...`

2. **Performance context** (when relevant):

   ```markdown
   Dropped index lookups from 12 queries/request to 1 by eager-loading the user association.
   ```

3. **Migration warnings** (when relevant):

   ```markdown
   **NOTE**: This migration adds a partial index on `users.hackatime_token`. On production volume, expect a second or two of lock time.
   ```

4. **Visual evidence** for UI changes: screenshots or short clips.

5. **API shape changes**: when you change the arguments, return type, or nil-ability of a public method on a model, service, job, or policy, note it in the PR body. If the method had a `sig`, quote the before/after `sig { ... }` lines.

6. **RBI regeneration**: if the PR updated files under `sorbet/rbi/dsl/` or `sorbet/rbi/gems/`, say so. Reviewers expect those to be committed and in sync with the Gemfile / schema / models.

### Never include

- Test plans. CI runs the tests; reviewers don't need a checklist.
- "Benefits" sections — benefits should be obvious from the technical description.
- Low-level implementation details — keep the description high-level.
- Marketing language. Stay technical and factual.

## Special Patterns

### Simple chore PRs

```markdown
Gem bump to resolve Dependabot alert: https://github.com/.../pull/...
```

### Bug fixes

Start with the broken behavior, then explain the fix:

```markdown
[What was broken and why it matters.]

[What changed to fix it.]
```

### Dependency bumps

Auto-generated Dependabot PRs don't need manual reformatting. Manual bumps can be one line:

```markdown
Bumps X to Y. Changes: https://github.com/...
```

## Creating PRs as Draft

Unless explicitly told otherwise, always create PRs as drafts:

```sh
gh pr create --draft --title "..." --body "..."
```

After creating, encourage review before promoting to ready:

> I've created draft PR #XXXX. Please review before marking as ready.

Only create non-draft PRs when the user explicitly asks, or when promoting an existing draft.

## Never include in the PR

- Claude co-author trailers. This project forbids them.
- Generated text that claims you tested something you didn't.
- Screenshots containing tokens, emails, or other private data.

## Key principles

1. Draft by default.
2. Concise — 1-2 paragraphs unless complexity demands more.
3. Technical — what and why, not detailed how.
4. Link everything: issues, related PRs, upstream changes.
5. Show impact: metrics for performance, screenshots for UI, warnings for migrations.
6. No test plans. No benefits sections.
