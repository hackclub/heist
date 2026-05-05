> **Load when**: first-time dev setup, resetting the local DB, or navigating an unfamiliar area of the codebase.
> **Skip when**: you already have the dev server running and know where the code lives. The procedural rules (commits, scope, type safety) are in [AGENTS.md](../../AGENTS.md), not here.

# Workflows

This doc holds the workflows that are not covered by topical docs. For everything else, jump directly to the topical guide.

## Topic index

| Topic                                | Doc                                              |
|--------------------------------------|--------------------------------------------------|
| Foundational rules, scope, commits   | [AGENTS.md](../../AGENTS.md)                     |
| Frontend (Hotwire, Stimulus, Tailwind) | [HOTWIRE.md](./HOTWIRE.md)                     |
| Figma implementation                 | [FIGMA.md](./FIGMA.md)                           |
| Models, controllers, services        | [RAILS.md](./RAILS.md)                           |
| Sorbet + Tapioca                     | [SORBET.md](./SORBET.md)                         |
| Migrations, schema, queries          | [DATABASE.md](./DATABASE.md)                     |
| Auth + Pundit                        | [AUTH.md](./AUTH.md)                             |
| Tests                                | [TESTING.md](./TESTING.md)                       |
| Errors and known failures            | [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)       |
| Recorded agent-failure patterns      | [LESSONS.md](./LESSONS.md)                       |
| PR descriptions                      | [PR_STYLE_GUIDE.md](./PR_STYLE_GUIDE.md)         |
| `docs/` markdown for `/docs`         | [DOCS_STYLE_GUIDE.md](./DOCS_STYLE_GUIDE.md)     |
| System overview                      | [ARCHITECTURE.md](./ARCHITECTURE.md)             |

## First-time setup

1. Ruby 3.4.4 (see `.ruby-version`) and Bundler installed.
2. Postgres running locally (Docker is fine; see README).
3. Copy `.env.development.example` to `.env` and fill in secrets.
4. `bundle install`.
5. `bin/rails db:setup`.
6. `bin/dev` (boots Rails + Tailwind watcher via `Procfile.dev`). Do NOT use `bin/rails s` alone; the Tailwind build will not run.
7. Visit `http://localhost:3000`.

## Resetting a bad dev database

Only when local data is unrecoverable and there is no in-progress work to lose:

```sh
bin/rails db:drop db:create db:migrate db:seed
```

Never run this against staging or production. Confirm before running.

## Adding a new endpoint

1. Add the route in `config/routes.rb`.
2. Generate the controller if needed: `bin/rails g controller Foo`.
3. Gate the action with Pundit (`authorize @record` or `policy_scope(Model)`). See [AUTH.md](./AUTH.md).
4. Add a controller test and a policy test. See [TESTING.md](./TESTING.md).
5. Verify the route: `bin/rails routes -g <pattern>`.

## Code navigation

| Task                               | Command                                       |
|------------------------------------|-----------------------------------------------|
| List routes                        | `bin/rails routes -g <pattern>`               |
| Inspect model schema               | `bin/rails runner "pp Project.columns_hash"`  |
| Find a controller's actions        | `bin/rails routes -c Projects`                |
| Grep source                        | `rg --type ruby 'pattern' app`                |
| Grep views                         | `rg '<%= render' app/views/`                  |
| Console (no HCB without approval)  | `bin/rails c`                                 |
| Jobs dashboard (admin)             | `/jobs`                                       |
| Mini-profiler (in dev)             | inline badge on every page                    |

## Investigation order

1. Start at `config/routes.rb` to understand the URL surface.
2. Trace into the controller, then the policy, then the model.
3. Check the matching `test/` files for expected behavior and edge cases.
4. For jobs: `app/jobs/` and the Mission Control dashboard at `/jobs`.