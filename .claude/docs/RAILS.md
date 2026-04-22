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

## Type safety (Sorbet + Tapioca)

The Heist uses Sorbet for gradual static typing and Tapioca to generate RBIs. `sorbet-runtime` ships in all environments; `sorbet` and `tapioca` are development-only.

### Daily commands

| Command                          | When                                                                              |
|----------------------------------|-----------------------------------------------------------------------------------|
| `bundle exec srb tc`             | Before finishing any change. Required tier with rubocop + brakeman.               |
| `bundle exec tapioca dsl`        | After touching a model, association, `enum`, scope, or job.                       |
| `bundle exec tapioca gem`        | After `bundle install` adds or upgrades a gem.                                    |
| `bundle exec tapioca dsl --verify` | In CI (and locally before pushing) to confirm DSL RBIs are in sync.             |

Commit every generated `sorbet/rbi/gems/*.rbi` and `sorbet/rbi/dsl/*.rbi` file. Drift in these files is the #1 reason CI fails on a typed project.

### Strictness ladder

- `# typed: false` (default, no sigil needed) — Sorbet checks syntax and constant resolution. Existing files.
- `# typed: true` — use on new service objects, new policies, new jobs, new form objects, new Data classes. Method-level type checks when `sig` is present.
- `# typed: strict` — every method must have a `sig`. Every instance variable must be annotated. Reserve for hot paths after the codebase is broadly typed. Not used yet.
- `# typed: ignore` — **banned.** Shopify's rule: "`typed: ignore` means `typed: debt`." If a file can't be typed, use `# typed: false`, not ignore.

### Writing a sig

```ruby
# typed: true
# frozen_string_literal: true

module HackatimeService
  extend T::Sig

  sig { params(code: String, redirect_uri: String).returns(T.nilable(T::Hash[String, T.untyped])) }
  def self.exchange_code_for_token(code, redirect_uri)
    # ...
  end
end
```

- `extend T::Sig` at the top of every class/module that defines sigs.
- `sig { ... }` immediately above the `def`. No blank line between them.
- `params(name: Type)` lists every argument. Kwargs too.
- `.returns(Type)` always. Use `.void` for methods that return nothing meaningful.
- `T.nilable(T)` for nil-able returns. Callers must handle nil.
- `T::Hash[K, V]`, `T::Array[V]`, `T::Set[V]` for collections.
- `T.untyped` as a last resort. Prefer to narrow.

### T::Struct and T::Enum

Prefer these over raw Hashes and stringly-typed values.

```ruby
class LeaderboardEntry < T::Struct
  const :user_id, Integer
  const :display_name, String
  const :hours, Float
  const :rank, Integer
end

class Ship::Status < T::Enum
  enums do
    Pending  = new("pending")
    Approved = new("approved")
    Returned = new("returned")
    Rejected = new("rejected")
  end
end
```

`T::Struct` fails loudly on missing or mistyped keys. `T::Enum` gives exhaustiveness in `case/when`.

For Rails-native enums on ActiveRecord models, use `enum :status, { pending: 0, approved: 1, returned: 2, rejected: 3 }`. Tapioca generates matching predicate/scope sigs in `sorbet/rbi/dsl/ship.rbi`.

### Escape hatches are code smells

- `T.unsafe(x)` — disables all type checks on `x`. Never use outside an RBI file.
- `T.must(x)` — asserts non-nil. Prefer `#fetch`, explicit guards, or `is_a?` narrowing.
- `T.cast(x, Type)` — runtime-checked type assertion. Prefer narrowing via control flow.
- `T.let(x, Type)` — annotates a local variable or `@ivar`. Fine to use; Sorbet often requires it for ivars in `typed: strict`.

If you reach for `T.must` or `T.unsafe`, leave a one-line comment explaining why the type system can't see the invariant.

### Rails-specific tricky spots

- **`ActiveSupport::Concern`**: Sorbet can't infer the host class. Annotate `requires_ancestor` in an `interface!` module, or accept `# typed: false` on the concern itself.
- **`find_by` vs `find`**: `find_by` returns `T.nilable(Model)`. `find` returns `Model` (or raises). Call sites must handle nil for `find_by`. Don't paper over with `&.`.
- **Strong params**: After `params.expect(...)`, coerce into a `T::Struct` or `Data.define` before handing off to a service object. Services take typed value objects, not `ActionController::Parameters`.
- **Polymorphic associations**: type the association as `T.untyped` or use `T.any(ModelA, ModelB)` if the set is closed.
- **`Current.user` / `current_user`**: nil in background jobs and public endpoints. Type as `T.nilable(User)` unless the controller guarantees a signed-in user.

### Pundit policies

`sorbet-typed` ships Pundit signatures. In your policies:

```ruby
# typed: true
class ProjectPolicy < ApplicationPolicy
  extend T::Sig

  sig { returns(T::Boolean) }
  def show?
    return false if record.discarded? && !admin?
    admin? || !record.is_unlisted || owner?
  end
end
```

The `record` is typed via Tapioca's DSL compiler for Pundit. `user` is `T.nilable(User)`.

### When a sig is wrong

- `srb tc` red: the signature doesn't match the implementation. Fix the sig or the code.
- Runtime `TypeError` from `sorbet-runtime`: someone called the method with the wrong type. Fix the caller, don't widen the sig.
- If the check level is too aggressive: `sig { ... .checked(:tests) }` runs the runtime check only in tests, not production. Use sparingly.

### Tapioca plugin ecosystem

- `tapioca-rails` — built in, handles ActiveRecord.
- `tapioca-pundit` — ships RBIs for Pundit base classes. Add to the Gemfile if you want richer policy typing.
- `tapioca-sorbet-typed` — community RBIs. Already pulled transitively.

Run `bundle exec tapioca annotations` periodically to fetch community-maintained RBIs for gems that don't ship their own.

### Migration strategy

Adopt at `typed: false` everywhere (the default). Ratchet files to `typed: true` as you touch them. Do not do a big-bang upgrade. Shopify ratcheted 99% of 75,000 files over several years.

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
