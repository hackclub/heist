# Database Development Patterns

## Database Work Overview

The Heist uses Postgres as its primary store via the `pg` gem. Solid Queue, Solid Cache, and Solid Cable all run against the same Postgres instance (with dedicated schemas in `db/queue_schema.rb`, `db/cache_schema.rb`, `db/cable_schema.rb`). The primary schema lives in `db/schema.rb`.

### Standard change flow

1. Generate the migration via CLI: `bin/rails g migration AddXToY x:type`.
2. Edit the migration if the generator didn't cover every column/index.
3. Run `bin/rails db:migrate` locally.
4. Run `bin/rails db:rollback` once to prove the `down` path works.
5. Run `bin/rails db:migrate` again.
6. Commit the updated `db/schema.rb` alongside the migration.

## Migration Guidelines

### File naming and location

- Location: `db/migrate/`.
- Format: `YYYYMMDDHHMMSS_description.rb` (generated automatically).
- Always reversible when possible. Use a `change` block; reach for `up`/`down` only when `change` cannot express the change.

### Reversibility

```ruby
class AddHackatimeTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :hackatime_token, :string
    add_index :users, :hackatime_token, unique: true, where: "hackatime_token IS NOT NULL"
  end
end
```

If you need `up`/`down`:

```ruby
class BackfillDefaults < ActiveRecord::Migration[8.1]
  def up
    User.where(role: nil).update_all(role: "user")
  end

  def down
    # Accept irreversibility only when truly necessary.
    raise ActiveRecord::IrreversibleMigration
  end
end
```

Avoid `raise IrreversibleMigration` when possible. A reversible migration is easier to roll back in an incident.

### Indexes

- Add an index whenever you add a foreign key or a uniqueness constraint.
- For columns you will frequently filter on (e.g., `projects.is_unlisted`), add a partial index.
- `add_index :table, :column, algorithm: :concurrently` when adding indexes to large existing tables — but only when running the migration against a Postgres that supports `CREATE INDEX CONCURRENTLY` (not in a transaction).

### Nullable fields

Rails translates `null: true` to the DB. In the model, handle nil explicitly:

```ruby
class User < ApplicationRecord
  def hackatime_linked?
    hackatime_token.present?
  end
end
```

Avoid sentinel strings (`"unset"`) for absence. Use `NULL` and check with `.nil?` / `.present?`.

### Enums and closed sets

When a column has a fixed, known set of valid values (`ship.status`, `user.role`), define it as a Rails `enum` with integer storage. This gives you:

- `ship.approved?`, `ship.pending?` predicates.
- `Ship.approved`, `Ship.pending` scopes.
- Exhaustiveness in `case/when`.
- A DB-level contract.
- Matching typed methods in `sorbet/rbi/dsl/ship.rbi` after `bundle exec tapioca dsl`.

```ruby
class Ship < ApplicationRecord
  enum :status, { pending: 0, approved: 1, returned: 2, rejected: 3 }
end
```

Never model a closed set as a free-text string column with "magic" values. If you need richer enum behavior in pure Ruby (outside ActiveRecord), use `T::Enum` — see `.claude/docs/RAILS.md`.

### Foreign keys

```ruby
add_reference :ships, :user, null: false, foreign_key: true
```

Always `foreign_key: true` unless the relationship genuinely is not a FK.

### Encrypted attributes

For tokens and secrets, use Rails' built-in encryption:

```ruby
class User < ApplicationRecord
  encrypts :hackatime_token
end
```

This encrypts at rest. Never store raw access tokens in plain columns.

### Soft delete

The project uses a `Discardable` concern. Migrations for discardable models should add `discarded_at:datetime` and an index:

```ruby
add_column :projects, :discarded_at, :datetime
add_index :projects, :discarded_at
```

Queries default to `.kept` or `.discarded`. See `app/models/concerns/discardable.rb`.

### Audit fields

`PaperTrail` tracks versions for models that `include PaperTrail::Model` (usually `has_paper_trail`). When adding attributes to an audited model, confirm the new attributes flow through PaperTrail. For sensitive attributes, configure `has_paper_trail ignore: [:foo]` so they don't end up in `versions.object`.

## Query patterns

### Avoid N+1

Use `includes` whenever a view or serializer iterates records and accesses an association:

```ruby
@ships = policy_scope(Ship).includes(:user, :project).order(created_at: :desc)
```

If you see logs like `SELECT * FROM users WHERE id = $1` repeating in a single request, you have an N+1.

### Scopes

```ruby
class Project < ApplicationRecord
  scope :listed, -> { where(is_unlisted: false) }
  scope :for_user, ->(user) { where(user: user) }
end
```

Scopes compose. Prefer them over class methods.

### `pluck` and `ids`

```ruby
user_ids = Project.kept.pluck(:user_id).uniq
```

`pluck` returns an Array. You can't chain ActiveRecord methods after it.

### `find_each`

For iteration over more than a few hundred records:

```ruby
Project.kept.find_each(batch_size: 500) do |project|
  # ...
end
```

### Transactions

Wrap multi-record writes in a transaction:

```ruby
ApplicationRecord.transaction do
  ship.update!(status: :approved)
  project.touch(:approved_at)
end
```

Inside a transaction, do not call external HTTP services — the transaction can hold a connection open while waiting on the network. If you need to call out, defer to a Solid Queue job enqueued after commit.

## Database best practices

### Schema design

1. Appropriate data types: `VARCHAR` / `TEXT` where relevant, `TIMESTAMP WITH TIME ZONE` for times.
2. Constraints: `NOT NULL`, `UNIQUE`, foreign keys where applicable.
3. Indexes for filtered/ordered columns.
4. Default values for booleans and enums.

### Query writing

1. Parameterized queries only. Never interpolate user input into SQL strings.
2. Handle `ActiveRecord::RecordNotFound` at controller level, not with `find_by` + nil-checks everywhere.
3. Use transactions for related writes.
4. Profile with `EXPLAIN` when queries look slow.

### Migration writing

1. Reversible whenever possible.
2. Test on a copy of realistic data when touching large tables.
3. One logical change per migration.
4. Don't rename columns without a two-step deploy plan (add new → backfill → switch reads → drop old).

## Common database issues

### Migration issues

- **Migration won't roll back** → Use `change_column_default` or `up`/`down`; `change_column` isn't reversible.
- **Schema conflict** → Pull latest schema, re-run migrations locally.
- **Concurrent index on small table fails** → Drop `algorithm: :concurrently` when it isn't needed; it adds overhead.

### Field handling

- **`null: false` without default** → Backfill in the same migration before switching `null: false`.
- **Unique index collides with existing rows** → Clean up duplicates in a prior migration.

### Query performance

- **Slow `ORDER BY created_at DESC`** → Add an index on `created_at` (or a covering composite index).
- **N+1 from Turbo Frames** → Add `.includes` in the controller that serves the frame.

## Testing database changes

```ruby
class ProjectTest < ActiveSupport::TestCase
  test "scope :listed excludes unlisted projects" do
    listed = projects(:public_project)
    unlisted = projects(:unlisted_project)
    assert_includes Project.listed, listed
    assert_not_includes Project.listed, unlisted
  end
end
```

After adding a migration, run the whole test suite to catch fixtures that don't match the new schema.

## Debugging

| Command                                                             | Purpose                                      |
|---------------------------------------------------------------------|----------------------------------------------|
| `bin/rails db:migrate:status`                                       | Show applied / pending migrations            |
| `bin/rails db:rollback`                                             | Roll back the last migration                 |
| `bin/rails runner "pp Project.columns_hash"`                        | Inspect columns from the command line        |
| `bin/rails dbconsole`                                               | Drop into psql                               |
| `EXPLAIN ANALYZE ...`                                               | Profile a specific query from psql           |

## Troubleshooting checklist

- [ ] Migration reversible (or explicitly `IrreversibleMigration`).
- [ ] `db/schema.rb` committed alongside migration.
- [ ] Foreign keys present where relationships exist.
- [ ] Indexes on filtered/ordered columns.
- [ ] Encrypted attributes for tokens and secrets.
- [ ] `null: false` columns have defaults or backfill.
- [ ] Discardable scopes (`.kept`) used where soft delete applies.
- [ ] PaperTrail flows through for new attributes on audited models.
