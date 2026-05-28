# Seed data

> **Load when**: you need to populate a local DB with realistic Heist activity (contributors, projects, approved ships) so the home dashboard, the segmented progress bar, or the activity feed has something to render.
> **Skip when**: you are debugging a specific record the user has in front of them, or working in a non-dev environment.

## Refuse to run in non-development

Every demo seed listed here aborts when `Rails.env.production?` is true. Do not invoke any of these against staging or production. If the user asks you to seed staging, stop and confirm in writing first.

## What's available

| Script                         | Creates                                                              | Touches HCB? |
|--------------------------------|----------------------------------------------------------------------|--------------|
| `db/seeds.rb`                  | One `StreamSession` and its `StreamSegment`s for the next weekend    | No           |
| `db/seeds/heist_demo.rb`       | ~30 demo contributors, 60 projects, 60 approved ships in the heist week | No        |

Both are idempotent — safe to re-run. They use `find_or_create_by!` keyed on stable identifiers (e.g., `email: "demo+slug@theheist.dev"`), so re-running adds nothing new and updates nothing.

## Quick reference

```sh
# Stream session/segments for this weekend (used by /stream view).
bin/rails db:seed

# Heist home dashboard data — contributors, projects, approved ships.
bin/rails runner db/seeds/heist_demo.rb
```

After running the demo seed, refresh `/` (signed in) — the segmented progress bar should fill ~11% with 60 hoverable segments fanning small-to-large left to right.

## What `db/seeds/heist_demo.rb` produces

- **Users** — 30 records with emails of the form `demo+<slug>@theheist.dev`. All have `roles: ["user"]`, a deterministic GitHub avatar URL, and a synthetic `slack_id` / `hca_id`.
- **Projects** — 2 per user, drawn from a fixed bank of heist-themed names + descriptions (`specter`, `spotiflight`, `lockpick`, etc.). The slug is suffixed with the user's first letter to avoid name collisions across users.
- **Ships** — 1–3 per user, all `status: :approved`, with `approved_seconds` pulled from a 35-bucket distribution running 5 minutes → 6 hours. `created_at` is offset within the heist week (`HEIST_WEEKEND_START` env var, default `2026-05-01T17:00:00Z`).
- After insertion, `Rails.cache.delete_matched("home/weekly_shipped_seconds/*")` invalidates the 60-second home-controller cache so the new data shows up immediately.

## Resetting demo data

There is no destructive teardown script — by design, since the user usually does not want their real fixtures wiped. If you need a clean slate:

```ruby
# In bin/rails console — destructive, asks for confirmation.
User.where("email LIKE ?", "demo+%@theheist.dev").destroy_all
```

`destroy_all` cascades through `dependent: :destroy` on `User#projects` and `Project#ships`, so this clears all demo data. Confirm with the user before running.

## Adding more demo data

If you need a wider distribution of ships or more contributors, edit the constants near the top of `db/seeds/heist_demo.rb` (`CONTRIBUTORS`, `PROJECT_BANK`, `SHIP_SIZES`) and re-run. Don't change the email pattern (`demo+<slug>@theheist.dev`) — the cleanup query above keys on it.

## Do not seed HCB

Per [AGENTS.md → Money and safety (HCB)](../../AGENTS.md#money-and-safety-hcb), never write a seed that touches HCB-related models, jobs, or external calls. If a feature you are demoing depends on HCB, stub the dependency in code rather than seeding fake HCB records.