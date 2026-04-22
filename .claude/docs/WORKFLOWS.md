# Development Workflows and Guidelines

## Quick Start Checklist for New Features

### Before Starting

- [ ] Run `git pull` to ensure you're on latest code.
- [ ] Does the feature touch the database? You'll need a migration.
- [ ] Does the feature touch authorization? You'll need a Pundit policy + policy test.
- [ ] Does the feature add or modify a model association / enum / scope / job? You'll need to regenerate DSL RBIs with `bundle exec tapioca dsl`.
- [ ] Does the feature touch money/HCB? STOP and get explicit written approval.

## Development Server

### Starting Development Mode

- Use `bin/dev` to start the app in development mode. It reads `Procfile.dev` and boots Rails, the Tailwind watcher, and any other dev processes together.
- Do NOT manually run `bin/rails s` alone when styles are changing — the Tailwind build won't run.
- Access the server at `http://localhost:3000`.

### First-time Setup

1. Ensure Ruby 3.4.4 (see `.ruby-version`) and Bundler are installed.
2. Start Postgres locally (Docker works: see README).
3. Copy `.env.development.example` to `.env` and fill in secrets.
4. `bundle install`.
5. `bin/rails db:setup`.
6. `bin/dev`.

### Resetting a bad dev database

If dev data is in a bad state and you are sure you want to destroy it:

```sh
bin/rails db:drop db:create db:migrate db:seed
```

Never run this against staging or production. Never run it without confirming you aren't about to lose in-progress local work.

## Code Style Guidelines

### Ruby Style

- Follow `rubocop-rails-omakase`. `.rubocop.yml` inherits it.
- `bin/rubocop -f github` is the source of truth. Run it before finishing.
- Use `# frozen_string_literal: true` at the top of new Ruby files.
- Prefer keyword arguments for methods with more than one argument.
- Private methods go at the bottom of the class.

### Type Checking (Sorbet)

- `bundle exec srb tc` must pass before finishing. Same tier as rubocop + brakeman.
- New service objects, policies, and jobs go in as `# typed: true` with `extend T::Sig` and a `sig` on every public method.
- Existing files stay at the default (`# typed: false`) until you touch them.
- Never use `# typed: ignore`.
- Regenerate DSL RBIs (`bundle exec tapioca dsl`) after model / association / enum / scope / job changes. Commit the resulting files in `sorbet/rbi/dsl/`.
- Regenerate gem RBIs (`bundle exec tapioca gem`) after `bundle install` adds or upgrades a gem. Commit the resulting files in `sorbet/rbi/gems/`.
- See `.claude/docs/RAILS.md` § Type safety for the full pattern library.

### Error Handling

- Use `rescue_from` in controllers for global concerns (e.g., `Pundit::NotAuthorizedError` is already handled in `ApplicationController`). Do not re-rescue it in child controllers.
- Raise descriptive exceptions at API boundaries. Service objects should raise domain-specific errors, not rescue-and-return-nil.
- Never silently swallow exceptions. If you `rescue`, log to Sentry or re-raise.

## Naming Conventions

- Names MUST tell what code does, not how it's implemented or its history.
- Follow Ruby/Rails conventions: snake_case methods and files, CamelCase classes, predicate methods end with `?`, bang methods end with `!`.
- NEVER use implementation details in names (e.g., `JSONUserSerializer`, `PundiWrappedPolicy`).
- NEVER use temporal/historical context in names (e.g., `LegacyProjectController`, `V2Ship`, `ImprovedHackatimeService`). When changing code, never document the old behavior or the behavior change.
- NEVER use pattern names unless they add clarity (prefer `Ship` over `ShipFactory`).
- Abbreviate only when the abbreviation is obvious (e.g., `HCA`, `HCB` — both project jargon).

### Comments

- Document non-obvious logic. Do not document the obvious.
- Code should describe what it does. Comments should describe why.
- Do not leave block comments or multi-paragraph docstrings on Ruby methods.
- Do not use emdash or endash. Use commas, semicolons, or periods.

## Database Migration Workflow

### Migration Guidelines

1. **Create migration files via the CLI**:

   ```sh
   bin/rails g migration AddShippedAtToShips shipped_at:datetime
   ```

2. **Verify reversibility**:
   - Always use a reversible `change` block when possible.
   - If you must use `up`/`down`, write both.
   - Run `bin/rails db:rollback` locally after migrating to prove the down path works, then migrate forward again.

3. **Commit the schema**:
   - `db/schema.rb` changes on migration. Commit it alongside the migration file.

4. **Updating queries**:
   - Data access goes in models and scopes, not controllers.
   - Add `.includes`/`.preload` where a new association is read in a view.

5. **Audit trails**:
   - `PaperTrail` auto-audits models that include `has_paper_trail`. When adding a new audited model, explicitly opt in; when adding attributes to an audited model, confirm they flow through.

6. **Long backfills**:
   - Use a Solid Queue job, not a migration, when touching more than a few thousand rows.

See `.claude/docs/DATABASE.md` for full patterns.

## API / Endpoint Development Workflow

### Adding a new endpoint

1. Add the route in `config/routes.rb`.
2. Generate the controller if needed: `bin/rails g controller Foo`.
3. Gate the action with Pundit: `authorize @record` or `policy_scope(Model)`.
4. Add a controller test and a policy test.
5. Run `bin/rails routes -g <pattern>` to verify the route.

### Turbo Stream responses

- Prefer Turbo Frames for partial page updates. Fall back to Turbo Streams for multi-region updates.
- Return Turbo Stream responses from the same controller action when possible (`respond_to` with `format.turbo_stream`).

## Testing Workflow

### Test Execution

- Full suite: `bin/rails test`
- Specific file: `bin/rails test test/models/project_test.rb`
- Specific test: `bin/rails test test/models/project_test.rb:42`
- System tests: `bin/rails test:system`

**Do NOT run tests or console code that touches HCB without explicit written approval.**

### Test Development

- Use fixtures in `test/fixtures/`. All fixtures load for every test.
- Tests run in parallel. Use unique identifiers in any test that creates records with unique constraints.
- Use `assert_no_difference` / `assert_difference` for record-count assertions.
- Prefer model and controller tests; reserve system tests for user-visible multi-page flows.

See `.claude/docs/TESTING.md` for details.

## Git Workflow

### Working on an existing branch

```sh
git fetch origin
git checkout branch-name
git pull origin branch-name
```

- Don't use `git push --force` unless explicitly requested.
- Prefer creating a new commit over `--amend` on a pushed branch.
- Don't skip hooks (`--no-verify`) unless the user explicitly asks for it.

## Commit Style

Format: `type(scope): message`. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

- Scope must be a real path or directory stem containing every changed file (e.g., `fix(app/policies): tighten ship visibility`).
- Omit scope for cross-cutting changes.
- Keep titles under ~70 characters.
- Use imperative, present tense.
- **Never include Claude co-author trailers.**

## Code Navigation and Investigation

Use Rails' own tooling first.

| Task                               | Command                                       |
|------------------------------------|-----------------------------------------------|
| List routes                        | `bin/rails routes -g <pattern>`               |
| Inspect model schema               | `bin/rails runner "pp Project.columns_hash"`  |
| Find a controller action           | `bin/rails routes -c Projects`                |
| Grep source                        | `grep -RIn --include='*.rb' 'pattern' app`    |
| Console into model                 | `bin/rails c` (never touch HCB without approval) |

### Investigation Strategy

1. Start with `config/routes.rb` to understand the URL surface.
2. Trace into the controller, then the policy, then the model.
3. Check `test/` for expected behavior and edge cases.
4. When touching jobs, look at `app/jobs/` and the Mission Control dashboard at `/jobs`.

## Troubleshooting Development Issues

- **Dev server won't start** → Ensure Postgres is running; check `.env`; run `bundle install`.
- **Assets missing / Tailwind not rebuilding** → Use `bin/dev`, not `bin/rails s`.
- **Migration errors** → Confirm reversibility; `bin/rails db:rollback` then re-migrate.
- **Pundit NotAuthorized in unexpected places** → Read the full policy before adjusting; add a policy test reproducing the issue first.
- **N+1 warnings in logs** → Add `.includes` or `.preload` for the association; verify the log is clean after.

See `.claude/docs/TROUBLESHOOTING.md`.
