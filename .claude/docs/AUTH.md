# Authentication and Authorization Guide

This project has two external OAuth providers and one internal authorization system:

- **HCA OAuth** (primary sign-in) — Hack Club Auth
- **Hackatime OAuth** (secondary link) — pulls coding hours
- **Pundit** (authorization) — policies gate every mutating or exposing action

## Sign-in (HCA OAuth)

HCA is the source of truth for who a user is. Profile fields (name, avatar, Slack handle) sync from HCA on sign-in.

- Entry point: `AuthController#new` → redirects to HCA.
- Callback: `AuthController#create` (`/auth/hca/callback`).
- Sign-out: `AuthController#destroy` (`DELETE /auth/signout`).
- Service object: `HcaService` (wraps HTTP calls to HCA).
- Concern: `Authentication` sets `Current.user`, `current_user`, and `user_signed_in?`.

### Do

- Use `current_user` and `user_signed_in?` in controllers and views.
- Use `Current.user` in models, jobs, and service objects where necessary. Scope writes to the acting user.
- Store the HCA `id_token` and refresh-token handling inside `HcaService`; don't leak tokens into controllers or views.

### Don't

- Don't reach into `session[...]` directly for user identity. Use the concern.
- Don't hand-roll OAuth state. `HcaService` already validates state.
- Don't rescue `Pundit::NotAuthorizedError` in child controllers — `ApplicationController` already handles it.

## Hackatime linking

Hackatime is a secondary OAuth that lets users link their coding-hour tracker. Linking is optional; the site must function if a user has not linked Hackatime.

- Entry point: `HackatimeAuthController`.
- Service object: `HackatimeService`.
- The link is represented on `User` (see the recent `Add Hackatime OAuth integration with user model methods` commit).

### Do

- Cache Hackatime API responses with `Rails.cache.fetch` and an explicit TTL.
- Fail gracefully. If Hackatime is down, the leaderboard should show stale-but-cached data, not error out.
- Sync hours in a background job (`SyncHackatimeHoursJob`-style), not inline in the request.
- Revoke stored tokens when a user unlinks.

### Don't

- Don't call Hackatime from a view or policy.
- Don't assume a user has linked Hackatime. Check before reading hours.

## OAuth compliance checklist

When touching any OAuth flow:

- [ ] Validate state parameter on callback.
- [ ] Store only what you need. Don't persist access tokens in the clear — use Rails' encrypted attributes.
- [ ] Short, explicit TTLs on cached profile data.
- [ ] On token refresh failure, clear the link and prompt the user to re-authorize, don't loop.
- [ ] Log failures to Sentry with enough context (provider, user id), never log tokens.

## Authorization (Pundit)

Every controller action that mutates or exposes records must be gated. The principle is strict: grant the minimum access needed for the feature to function.

### Policy structure

- Policies live in `app/policies/`, named `<Model>Policy`.
- `ApplicationPolicy` is the base class and defines the `Scope` pattern.
- Subclasses override `#resolve` in `Scope` to filter records by visibility and ownership.

Example (existing `ProjectPolicy`):

```ruby
class ProjectPolicy < ApplicationPolicy
  def show?
    return false if record.discarded? && !admin?
    admin? || !record.is_unlisted || owner?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.kept.listed.or(scope.kept.where(user: user))
      end
    end
  end
end
```

Notes:

- `scope.kept` respects soft delete.
- Admins get everything.
- Regular users get listed records plus their own.

### Usage in controllers

```ruby
def index
  @projects = policy_scope(Project).includes(:user)
end

def show
  @project = Project.find(params[:id])
  authorize @project
end
```

### Do

- Add or update a policy test in `test/policies/` for every policy change.
- Reuse helpers: `admin?`, `owner?`, `user.present?`.
- Use `policy_scope(Model)` in `index`. Don't reimplement scoping.
- Soft-delete-aware: return `false` for discarded records unless the user is an admin.
- Read the full policy before editing. Helpers and early returns may already cover your case.

### Don't

- Don't grant access broader than the feature requires.
- Don't add bypass flags (`skip_authorization`) without approval.
- Don't gate only on `user.present?` when ownership matters.
- Don't rescue `Pundit::NotAuthorizedError` in controllers — it's handled globally.

## Admin access

Admins are identified by a role on `User` (see `UserPolicy` and `Admin::*` controllers). Admin access implies elevated trust; changes to admin-checking code need careful review.

## Troubleshooting

| Symptom                                               | Cause / Fix                                                      |
|-------------------------------------------------------|------------------------------------------------------------------|
| `NotAuthorizedError` on a page the user should see    | Re-read the policy. Check `Scope#resolve`. Add a policy test.    |
| HCA sign-in loop                                      | State mismatch or cookie issue. Check `HcaService` logs.         |
| Hackatime sync runs on every request                  | Move to a background job and cache the last-sync timestamp.      |
| Leaderboard empty when Hackatime is down              | Cache should serve stale values. Check `Rails.cache.fetch` TTL.  |
| `Current.user` is nil inside a job                    | Set it at job start from the job's `user_id` argument.           |

## Type safety for auth code

Policies and services in the auth path should be `# typed: true` from day one.

- `current_user` and `Current.user` are `T.nilable(User)` — nil in background jobs, nil for anonymous controllers.
- `Pundit::Authorization#authorize` raises `Pundit::NotAuthorizedError` (caught globally); its return type is `T.untyped` in Pundit's stock RBIs. Don't rely on its return value.
- `policy_scope(Model)` returns `ActiveRecord::Relation`. Chain `.includes` / `.where` freely.
- `HcaService` and `HackatimeService` public methods should return a typed shape (a `T::Struct` or `T.nilable(T::Hash[String, T.untyped])` for raw API responses). Callers must handle nil.

Example:

```ruby
# typed: true
class HcaService
  extend T::Sig

  sig { params(code: String, redirect_uri: String).returns(T.nilable(HcaSession)) }
  def exchange(code:, redirect_uri:)
    # ...
  end
end

class HcaSession < T::Struct
  const :access_token, String
  const :user_id, Integer
  const :expires_at, Time
end
```

## Security checklist before completing auth work

- [ ] Policies gate every new or modified action.
- [ ] Policy tests added/updated.
- [ ] Strong parameters whitelist only the fields the policy permits.
- [ ] No token or secret in logs or error messages.
- [ ] Encrypted attributes used for stored tokens.
- [ ] `bin/brakeman --no-pager` clean for your changes.
- [ ] Manual smoke test: signed-out, signed-in non-admin, signed-in admin.
