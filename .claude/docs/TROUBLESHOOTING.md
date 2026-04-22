# Troubleshooting Guide

## Common Issues

### Dev server

1. **`bin/dev` won't start**
   - Postgres isn't running. Start it (Docker or local).
   - Missing env vars. Copy `.env.development.example` to `.env`.
   - Bundler out of date. `bundle install`.

2. **Tailwind styles not updating**
   - You're running `bin/rails s` instead of `bin/dev`. Switch to `bin/dev`.
   - The Tailwind watcher crashed. Check the other pane in the `bin/dev` output.

3. **Importmap module not found**
   - `bin/importmap pin <name>` after adding a new dependency.
   - Clear the cache: `rm -rf tmp/importmap`.

### Database

4. **Migration won't apply**
   - Check `bin/rails db:migrate:status` to see the pending list.
   - Stale `schema.rb` in git. Pull latest and re-migrate.

5. **Migration is irreversible but shouldn't be**
   - Use a `change` block where possible. `change_column` is not reversible — use `up` / `down`.

6. **Unique-index violation in tests**
   - Parallel tests collided. Use unique identifiers (`SecureRandom.hex`).

7. **`ActiveRecord::ConnectionNotEstablished`**
   - Postgres stopped, or the database URL in `.env` is wrong.

### Authorization

8. **`Pundit::NotAuthorizedError` on a page the user should see**
   - Re-read the policy *all the way through*. Check the `Scope`.
   - Write a failing policy test that reproduces the issue before changing the policy.
   - Don't rescue the error in a child controller — it's handled globally.

9. **Policy test passes but UI still forbids**
   - Controller likely calls `authorize` on a different record than you think. Add `pp @record` temporarily.

### Auth (HCA / Hackatime)

10. **HCA sign-in loops**
    - State mismatch. Cookies may be blocked or the callback URL mismatches HCA config.
    - Check `HcaService` logs in Sentry.

11. **Hackatime sync runs on every request**
    - Move to a Solid Queue job. Cache `last_synced_at` on the user.

12. **Hackatime outage takes down the leaderboard**
    - `Rails.cache.fetch` the leaderboard with a TTL; fall back to the cached value on service error.

### Jobs

13. **Job stuck in pending**
    - Solid Queue worker isn't running. Check `bin/dev` output or Mission Control at `/jobs`.

14. **Job retries infinitely**
    - The job isn't idempotent, or the rescue logic swallows the poison-pill condition. Make the job idempotent; add a retry limit.

### Turbo / Stimulus

15. **Turbo Frame fetches the full page**
    - The response doesn't include a matching `<turbo-frame id="...">`. Inspect the response HTML.

16. **Stimulus controller never fires**
    - Controller file name doesn't match the `data-controller` value, or the Importmap pin is missing.

17. **Form submit triggers a full page reload instead of Turbo Stream**
    - Missing `format.turbo_stream` in the controller action or missing `data-turbo-stream` on the form.

### Caching

18. **Stale fragment after model update**
    - Add `touch: true` to the child's `belongs_to`, or invalidate explicitly in a model callback.

19. **Cache fills with per-user keys and evicts quickly**
    - Move from per-user caching to per-resource caching, or raise the Solid Cache size.

### Observability

20. **Sentry not reporting**
    - `SENTRY_DSN` missing in env. In development Sentry is usually off by design.

21. **Skylight missing data**
    - `SKYLIGHT_AUTHENTICATION` missing. Development is off by default.

## Systematic Debugging Approach

**YOU MUST ALWAYS find the root cause of any issue you are debugging.**

**YOU MUST NEVER fix a symptom or add a workaround instead of finding a root cause, even if it is faster.**

### Multi-issue problem solving

When several tests or integrations fail at once:

1. **Identify root causes**:
   - Run failing tests individually to isolate.
   - Read error messages carefully — both the failure line and any wrapped exceptions.
   - Reproduce consistently before investigating.
   - Check recent changes: `git log`, `git diff`.
   - When you don't know, say "I don't understand X" rather than pretending to know.

2. **Fix in logical order**:
   - Load errors / undefined constants first.
   - Authorization (Pundit) next.
   - Business-logic / validation next.
   - Edge cases and race conditions last.
   - If your first fix didn't work, STOP and re-analyze. Don't stack more fixes on a wrong hypothesis.

3. **Verify**:
   - Test each fix individually before moving on.
   - Run `bin/rubocop -f github` and `bin/brakeman --no-pager` after database or auth changes.
   - Run the full suite before considering the task complete (excluding HCB without approval).

## Debug Commands

| Command                                              | Purpose                                  |
|------------------------------------------------------|------------------------------------------|
| `bin/rubocop -f github`                              | Lint                                     |
| `bin/brakeman --no-pager`                            | Security scan                            |
| `bin/rails test`                                     | Full test suite                          |
| `bin/rails db:migrate:status`                        | Migration status                         |
| `bin/rails routes -g pattern`                        | Inspect routes                           |
| `bin/rails runner "code"`                            | One-off Ruby in the Rails env            |
| `bin/rails c`                                        | Console (NEVER touch HCB without approval) |
| `bin/rails log:clear`                                | Clear dev logs                           |

## Common Error Messages

### Rails errors

**`NoMethodError: undefined method 'foo' for nil:NilClass`**

- Cause: a value you assumed was present was nil. Often a `find_by` returning nil, a missing `has_one` record, or a Hackatime API response with a missing field. This is the single biggest bug class Sorbet catches — if it fires in production, your sig is wrong or the caller is untyped.
- Fix: locate the first nil, guard it with `return` or an explicit branch. Do not sprinkle `&.` everywhere — fix the source. If the method is typed, update the sig to `T.nilable(...)` and handle nil at the call site.

**`NameError: uninitialized constant Foo::Bar`**

- Cause: autoload miss, typo, or missing `require`. Often a file path that doesn't match Zeitwerk conventions (e.g., `lib/constraints/admin_constraint.rb` defining `AdminConstraint` instead of `Constraints::AdminConstraint`).
- Fix: check that the file path matches Zeitwerk (snake_case file for CamelCase constant). If it's a legitimate exception (like `lib/constraints/`), add the directory to `config.autoload_lib(ignore: [...])` and keep the `require_relative` that loads the file.
- At `# typed: true` or higher, Sorbet catches these at check time. Run `bundle exec srb tc`.

**`ActiveRecord::RecordNotFound`**

- Cause: `.find` with an ID that doesn't exist, or a stale link.
- Fix: Let the default 404 handler deal with it unless you need a custom UX.

**`ActiveRecord::NotNullViolation`**

- Cause: Missing required field, or migration without default for `null: false`.
- Fix: Backfill, then switch `null: false` in a second migration.

**`ActiveRecord::InvalidForeignKey`**

- Cause: Deleting a parent with children, or inserting a child with a nonexistent parent.
- Fix: Add the missing record, or add `dependent: :destroy` / `dependent: :nullify` on the parent association (think about the semantics first).

**`ActionController::ParameterMissing`**

- Cause: `params.require(:foo)` but `:foo` wasn't in the payload.
- Fix: Check strong parameters; ensure the form sends the nested key.

### Pundit errors

**`Pundit::NotAuthorizedError`**

- Cause: Policy returned false.
- Fix: Write a policy test that reproduces, then adjust the policy. Don't widen without thinking.

**`Pundit::AuthorizationNotPerformedError`**

- Cause: Controller action forgot `authorize` / `policy_scope`.
- Fix: Add it. Do not add `skip_authorization` as a workaround.

### Hotwire errors

**`Turbo::FrameMissingError`**

- Cause: Turbo Frame request but the response has no matching frame id.
- Fix: Return a frame with the expected id, or redirect.

## Prevention Strategies

### Before making changes

1. Read the relevant section of `.claude/docs/`.
2. Check similar patterns already in the codebase.
3. Understand the policy for the records you'll touch.
4. Plan database changes (migration + schema + backfill).

### During development

1. Run tests frequently: `bin/rails test test/path/to/specific_test.rb`.
2. Tail the Rails log to catch N+1s and unexpected SQL.
3. Use `binding.break` (debug gem) or `binding.irb`, remove before committing.

### Before committing

1. `bin/rubocop -f github` clean for your change.
2. `bin/brakeman --no-pager` clean for your change.
3. `git diff` reviewed — no stray `pp`, `binding.irb`, or unrelated edits.
4. No Claude co-author trailers.

## Getting Help

- Check existing similar implementations in the codebase first.
- Read the related test files for expected behavior.
- Sentry captures uncaught errors; search by the error message.
- Skylight has perf traces; use them before optimizing blindly.

## Debug Info to Collect

When asking for help, include:

1. Exact error message and stack trace.
2. Steps to reproduce.
3. Relevant code snippet (with path and line).
4. Test output if applicable.
5. Rails env (development/test/production) and Ruby/Rails version.
