# The Heist Architecture

This document provides an overview of The Heist's architecture and core systems.

## What is The Heist?

The Heist is Hack Club's weekend-long streaming program. Students collectively log coding hours toward a 1,000-hour goal to unlock shared grants and prizes. Participants submit projects and link Hackatime so their hours roll up into a live, community-wide leaderboard. Dhamari streams the event on YouTube and the feed is embedded on a dedicated stream page on the platform.

The app is public-facing: sign-in, ship submission, the stream page, and the leaderboard are visible to the community in real time. Regressions in these paths are visible immediately to participants.

## Core Architecture

The Heist is a Rails 8.1 monolith running Ruby 3.4.4. It uses server-rendered HTML with Hotwire (Turbo + Stimulus) and Tailwind CSS 4, served through Importmap (no bundler). Background work runs on Solid Queue, caching on Solid Cache, and Action Cable on Solid Cable — all backed by the same Postgres instance as the primary data store.

Authorization is enforced via Pundit policies on every controller action that mutates or exposes records. Authentication is handled by the `Authentication` concern, which sets `Current.user` and `current_user`. Sign-in is HCA OAuth; Hackatime OAuth is a secondary account link used to pull coding hours.

External services (HCA, Hackatime, YouTube, Ferret) are encapsulated in service objects under `app/services/`. Health checks via OkComputer guard optional integrations so that an outage in, say, Ferret does not take down the home page.

## Request Lifecycle

1. **Rack::Attack** throttles and filters abusive requests at the edge.
2. **Ahoy** tracks the visit and, for signed-in users, associates it with the user.
3. **Authentication concern** sets `Current.user`.
4. **Controller action** runs, usually gated by Pundit (`authorize @record` or `policy_scope(Model)`).
5. **Views** render with Turbo Frames/Streams for partial updates; Stimulus controllers handle client behavior.
6. **PaperTrail** records audit events on mutations to audited models.
7. **Sentry + Skylight + OpenTelemetry** capture errors, performance, and traces.

## Domain Model

| Model               | Purpose                                                             |
|---------------------|---------------------------------------------------------------------|
| `User`              | HCA-authenticated account; may link Hackatime                       |
| `Project`           | User-owned project; tagged, has visibility and soft-delete          |
| `Ship`              | A submission of a project for review (pending/approved/returned/rejected) with frozen, encrypted snapshots |
| `StreamSession`     | A live stream instance                                              |
| `StreamSegment`     | A scheduled or recorded segment within a session                    |
| `StreamAppearance`  | Participants who appeared on stream                                 |
| `Session`           | Devise-style sign-in sessions                                       |
| `Ahoy::Visit`, `Ahoy::Event` | Analytics                                                  |

## Controllers

| Area           | Controller                                     | Purpose                                            |
|----------------|------------------------------------------------|----------------------------------------------------|
| Landing        | `LandingController`                            | Public marketing page                              |
| Home           | `HomeController`                               | Signed-in home                                     |
| Auth           | `AuthController`, `HackatimeAuthController`    | HCA OAuth + Hackatime linking                      |
| Projects       | `ProjectsController`                           | CRUD with tagging and visibility                   |
| Ships          | `Admin::ShipsController`                       | Review workflow                                    |
| Admin          | `Admin::*`                                     | Users, projects, ships, jobs                       |
| Docs           | `MarkdownController`                           | File-based Markdown with caching                   |
| Bans           | `BansController`                               | Moderation                                         |

## API Design

Most client traffic is server-rendered HTML with Turbo. Where JSON is needed, it uses `jbuilder` and lives under `/api/`. There is no versioned public API yet. When you add an endpoint:

- Gate it with Pundit.
- Return Turbo Stream responses from the same controller action (`respond_to` with `format.turbo_stream`) where possible.
- Prefer path parameters (`/projects/:id`) over query parameters for resource identity.

## Authorization System

Pundit enforces role-based access. Every policy lives in `app/policies/` with a matching `test/policies/*_test.rb`. The `ApplicationPolicy` base class defines the `Scope` pattern; subclasses override `#resolve` to filter records by visibility and ownership.

Principle of least privilege is strict:

- `admin?`, `owner?`, and similar helpers already exist; reuse them.
- Never grant access you don't need for the feature to function.
- When modifying a policy, read the whole file first. Helpers may already cover your case.

## Background Jobs and Scheduling

- Solid Queue handles all jobs. Jobs live in `app/jobs/`.
- Recurring schedules are declared in `config/recurring.yml`.
- The dashboard is mounted at `/jobs` behind admin auth.
- Jobs must be idempotent; assume retries.

## External Integrations

| Integration        | Service object                 | Purpose                              |
|--------------------|--------------------------------|--------------------------------------|
| HCA OAuth          | `HcaService`                   | Sign-in + profile sync               |
| Hackatime OAuth    | `HackatimeService`             | Coding-hour tracking                 |
| Ferret             | `FerretService`                | Search index (optional in dev)       |
| YouTube stream     | `StreamService`                | Live-feed metadata/embed             |

All external calls route through service objects. Never call an external service directly from a view, a policy, or inline in a controller.

## Storage

- **Active Storage** backs file uploads.
- **Cloudflare R2** in production (`R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_ENDPOINT`).
- Local disk in development.
- `image_processing` handles variants.

## Observability

- **Sentry** for error tracking (context via `SentryContext` concern).
- **Skylight** for performance monitoring.
- **OpenTelemetry** (`OtelContext` concern) for traces.
- **Ahoy** for visit/event analytics and UTM attribution.

## Deploy

- **Kamal** drives the deploy (`bin/kamal deploy`).
- **Thruster** fronts Puma for HTTP caching/compression.
- Kamal config lives in `.kamal/` and `config/deploy.yml`.
- Never deploy without explicit approval.

## Money and HCB

**HCB controls money for the program. DO NOT EDIT any code related to HCB without explicit written approval.** Alert in the chat before making changes to HCB code. Do not run tests or console code that touches HCB without explicit written approval.

## Type Safety

The Heist uses **Sorbet** (static + runtime type checker) with **Tapioca** (RBI generator). Configuration lives in `sorbet/`:

- `sorbet/config` — Sorbet CLI flags.
- `sorbet/rbi/gems/` — auto-generated signatures for every gem (run `bundle exec tapioca gem` after `bundle install`).
- `sorbet/rbi/dsl/` — auto-generated signatures for Rails DSLs: ActiveRecord columns and associations, enum methods, URL helpers, Pundit policies (run `bundle exec tapioca dsl` after any model/association/enum/scope/job change).
- `sorbet/tapioca/require.rb` — preloads required to make RBI generation work, plus a small monkey-patch that restores `has_rest` / `has_keyrest` on `T::Private::Methods::Signature` (tapioca 0.19.0 vs. sorbet-runtime 0.6.13153 mismatch — remove when upstream ships a fix).

**Strictness ladder** (Shopify convention):

- `# typed: false` — default. Syntax + constant resolution only. Existing files.
- `# typed: true` — new service objects, policies, jobs. Method-level checks when `sig` is present.
- `# typed: strict` — reserve for hot paths where every method must have a `sig`. Not used yet.
- `# typed: ignore` — **banned**. It silences errors in downstream files.

**Runtime behavior**: `sorbet-runtime` is a runtime gem (ships in all environments). Every `sig` is wrapped at load time so arg and return types are validated at runtime. Default check level is `:always`. Narrow with `.checked(:tests)` on hot methods if profiling shows overhead.

See `.claude/docs/RAILS.md` for concrete `T::Struct`, `Data.define`, and `sig` patterns.

## Testing Framework

- **Minitest** with fixtures (all fixtures load for every test).
- **Parallel** by default: `parallelize(workers: :number_of_processors)`.
- **Capybara + Selenium** for system tests.
- Every policy has a policy test. Every new controller action has a controller test.

See `.claude/docs/TESTING.md` for patterns.

## Development Philosophy

- Hotwire first: Turbo before custom JavaScript, Stimulus before inline scripts.
- Principle of least privilege for Pundit.
- Keep AGENTS.md and this document lean and actionable. Detailed runbooks belong in `.claude/docs/`.
- Conventional commits: `type(scope): message`.
