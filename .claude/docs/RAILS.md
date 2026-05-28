> **Load when**: writing models, controllers, scopes, or service objects, or in doubt about Rails 8 / Ruby 3.4 idioms.
> **Skip when**: view-only or pure JS/CSS changes.

# Modern Rails (8.x) and Ruby 3.4

Reference for writing idiomatic Rails in this codebase. Respect the versions declared in `.ruby-version` (3.4.4) and `Gemfile` (Rails ~> 8.1). Do not emit features from a version newer than what the project declares.

## How modern Rails thinks differently

**Solid trio** (Rails 8): Solid Queue, Solid Cache, and Solid Cable are the defaults for jobs, caching, and Action Cable, all backed by the primary Postgres database. No separate Redis is required for these (this project does keep Redis available via the `redis` gem for other uses, but the trio does not depend on it).

**Hotwire** (Rails 7+): Turbo + Stimulus replace most SPA needs. Use Turbo Frames for partial page updates and Turbo Streams for multi-region updates. Reach for Stimulus for client behavior. Never inline `<script>` in templates.

**Importmap** (Rails 7+): No bundler. JavaScript modules load directly from the browser via an import map. If you add a JS dependency, pin it with `bin/importmap pin <name>`.

**Kamal** (Rails 8): First-class deploy target. Config lives in `.kamal/` and `config/deploy.yml`.

**Propshaft** (Rails 7+): Asset pipeline. Simpler than Sprockets. Files in `app/assets/` are served as-is with digests.

**Ruby 3.4** features to use where appropriate:

- Data classes (`Data.define(:x, :y)`) for immutable value objects.
- Pattern matching (`case ... in ...`) for destructuring and dispatching on shape.
- Endless method definitions (`def foo = 1`) for one-liners.
- `it` as an implicit block parameter (Ruby 3.4).
- Keyword-argument-only APIs for methods with more than one argument.

## Replace these patterns

| Old pattern                                          | Modern replacement                                         |
|------------------------------------------------------|------------------------------------------------------------|
| `Struct.new(:x, :y)` for immutable value object      | `Data.define(:x, :y)`                                       |
| Nested `case/when` with type checks                  | `case ... in ...` pattern matching                         |
| Manual `each_with_object({})` to build hashes        | `to_h { |x| [k, v] }`                                      |
| `Rails.logger.info "msg #{x}"`                       | `Rails.logger.info { "msg #{x}" }` (lazy)                  |
| `ActiveRecord::Base.transaction`                     | `Model.transaction` on the model that owns the write      |
| `where("status = ?", :open)`                         | `where(status: :open)` + an enum                           |
| Sidekiq / Resque / Delayed::Job                      | Solid Queue (`ApplicationJob`)                             |
| Redis::Store / dalli                                 | Solid Cache                                                |
| AnyCable / redis pub/sub                             | Solid Cable                                                |
| jQuery click handler                                 | Stimulus controller                                        |
| `render partial: ...` from a controller              | Turbo Frame or Turbo Stream response                       |
| Webpacker / esbuild-rails                            | Importmap (this project) or jsbundling-rails (not used)    |
| Sprockets                                            | Propshaft                                                  |
| `before_filter`                                      | `before_action`                                            |
| `update_attributes`                                  | `update`                                                   |
| `find_by_name(x)`                                    | `find_by(name: x)`                                         |
| `has_many :x, conditions: ...`                       | scoped association with a block or a scope                 |
| String SQL conditions                                | Arel or hash conditions                                    |
| `attr_accessible`                                    | Strong parameters in the controller                        |

## ActiveRecord patterns

- **Scopes over class methods**: `scope :published, -> { where(published: true) }` composes better than a bare class method.
- **`includes` vs `preload` vs `eager_load`**: use `includes` unless you know you need one of the others.
- **`pluck` returns an Array, not ActiveRecord::Relation**. Don't chain ActiveRecord methods after it.
- **`find_each` / `in_batches`** for iterating more than a few hundred records.
- **Avoid `default_scope`.** It silently filters and is easy to forget. Use an explicit scope.
- **`touch: true`** on associations invalidates cache keys of parents when children change.
- **Discardable**: this project uses a `Discardable` concern for soft delete. Scope with `.kept`.

## Controllers

- Thin controllers. Push logic to models, services, or form objects.
- `authorize @record` or `policy_scope(Model)` in every mutating or exposing action.
- Use `respond_to` with `format.html` + `format.turbo_stream` for partial updates.
- Strong parameters: always whitelist with `params.expect(...)` (Rails 8) or `params.require(...).permit(...)`.

## Views

- Partials and helpers for reuse. Never copy-paste markup between views.
- Use `tag.*` helpers (`tag.div`, `tag.span`) instead of hand-written HTML in helpers.
- Use `content_tag` only in legacy code; new code should use `tag.*`.
- Fragment caching for expensive partials: `cache [record, :variant]`.

## Stimulus

- One responsibility per controller. Small, named targets.
- File name matches controller name: `foo_controller.js` exports `FooController`.
- Register implicitly via the Stimulus Importmap loader; you usually don't need to touch `application.js`.
- Never reach into the DOM outside the controller's element.
- Use `data-*` attributes for configuration; don't read `window.*`.

## Jobs

- Inherit from `ApplicationJob`.
- Use keyword arguments.
- Idempotent by construction: the job should produce the same result if retried.
- Name jobs by what they do (`SyncHackatimeHoursJob`), not by cadence or implementation (`HourlyJob`, `SidekiqHackatimeWorker`).

## Service objects

- One public method per service (`call`), or a named action method.
- Construct with dependencies in the initializer; pass inputs to the method.
- Raise domain-specific exceptions; don't return nil-or-string sentinels.
- Wrap external calls with a timeout and a Sentry breadcrumb.

## Error handling

- `rescue_from` in `ApplicationController` for cross-cutting concerns (already set up for `Pundit::NotAuthorizedError`).
- Never `rescue` without logging or re-raising.
- Use `StandardError` subclasses for domain errors. Never `rescue Exception`.
- Always include context in error messages (IDs, not just "failed").

## Type safety

Sorbet + Tapioca is the type system. The full runbook (sig syntax, `T::Struct`, `T::Enum`, escape hatches, Pundit/AR specifics, error patterns) lives in [SORBET.md](./SORBET.md). Three rules to remember:

- `bundle exec srb tc` must pass before finishing.
- New service objects, policies, jobs, and form objects start at `# typed: true` with `extend T::Sig` and a `sig` on every public method.
- After model / association / enum / scope / job changes, run `bundle exec tapioca dsl` and commit the updated RBIs.

## Pitfalls

**Version misuse.** Don't reach for Rails 8.2 / Ruby 3.5 features. This project is Rails 8.1.2 / Ruby 3.4.4.

**`default_scope` regret.** It applies to every query, including through associations, and is easy to forget. Use explicit scopes (`.published`, `.kept`).

**`pluck` is terminal.** It returns an Array. You can't chain `.where` after it.

**N+1 through Turbo Frames.** A Turbo Frame fetch re-runs the index query for one record. Check your logs — it's easy to miss.

**Callbacks that call `save`.** Callbacks that mutate the record being saved can loop or produce surprising state. Prefer service objects for anything non-trivial.

**Inline JS in ERB.** Promote to a Stimulus controller. No exceptions.

**Ignoring the fixture system.** All fixtures load for every test. If you add a fixture, verify it doesn't break unrelated tests.

## Behavioral changes in recent Rails

- Strong parameters require explicit permit; `require`/`permit` are not optional.
- `ActiveStorage` URLs are signed by default; don't hand-roll.
- `has_one_attached` supports `variant` pre-declaration; use it instead of on-the-fly variants in views.
- `ActionCable` is replaced by Solid Cable in defaults.
- `Rails.cache` is Solid Cache, backed by Postgres.
