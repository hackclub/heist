# Testing Patterns and Best Practices

## Overview

The Heist uses Rails Minitest with fixtures. All fixtures in `test/fixtures/*.yml` load for every test. Tests run in parallel (`parallelize(workers: :number_of_processors)`), so any shared resource with a unique constraint needs unique identifiers per test.

**Do NOT run tests or console code that touches HCB without explicit written approval.**

## Avoiding race conditions

Because tests run in parallel:

1. **Unique identifiers**: Never use a hardcoded name in a test that creates a record with a unique constraint.

   ```ruby
   # Good
   email = "test-#{name}-#{SecureRandom.hex(4)}@example.com"

   # Bad
   email = "test@example.com"
   ```

2. **Database constraints**: Know the unique indexes on the table you are testing. Generate unique values for every constrained column.

3. **Avoid `Time.current` in assertions** unless you've frozen time. Use `travel_to` / `freeze_time`.

4. **Avoid `Rails.cache` leakage between tests**. The test environment uses an isolated cache, but explicitly `Rails.cache.clear` in `setup` if your test depends on a fresh cache.

## Test Categories

| Category         | Location                | When                                              |
|------------------|-------------------------|---------------------------------------------------|
| Model tests      | `test/models/`          | Validations, scopes, associations, domain logic   |
| Controller tests | `test/controllers/`     | Routing + action behavior, strong params          |
| Policy tests     | `test/policies/`        | Every Pundit rule                                 |
| Integration      | `test/integration/`     | Multi-controller flows                            |
| System           | `test/system/`          | User-visible browser flows (Capybara + Selenium)  |

## Test Organization

### File structure

Mirror the source tree:

```
app/models/project.rb          → test/models/project_test.rb
app/controllers/projects_controller.rb → test/controllers/projects_controller_test.rb
app/policies/project_policy.rb → test/policies/project_policy_test.rb
```

### Test naming

```ruby
class ProjectTest < ActiveSupport::TestCase
  test "scope :kept excludes discarded records" do
    # ...
  end
end
```

Use descriptive test names. The test name should describe the behavior, not the method under test.

## Test Commands

| Command                                              | Purpose                                  |
|------------------------------------------------------|------------------------------------------|
| `bin/rails test`                                     | Full suite                               |
| `bin/rails test test/models/project_test.rb`        | One file                                 |
| `bin/rails test test/models/project_test.rb:42`     | One test by line number                  |
| `bin/rails test:system`                              | System tests only                        |
| `bin/rails test test/policies/`                      | All policy tests                         |

## Common Testing Patterns

### Record creation

Prefer fixtures over inline `create!` where the data is generic. Use `create!` with unique fields when the test needs specific data.

```ruby
test "approves a pending ship" do
  ship = ships(:pending_ship)
  ship.approve!
  assert ship.approved?
end
```

### Authentication in controller tests

```ruby
test "index requires signed-in user" do
  get projects_path
  assert_redirected_to signin_path
end

test "index lists the user's projects when signed in" do
  sign_in_as users(:regular)
  get projects_path
  assert_response :success
end
```

Implement `sign_in_as` once in `test_helper.rb` or an integration test helper; don't re-implement per test.

### Policy tests

```ruby
class ProjectPolicyTest < ActiveSupport::TestCase
  test "admin can show a discarded project" do
    policy = ProjectPolicy.new(users(:admin), projects(:discarded))
    assert policy.show?
  end

  test "owner cannot show after discard" do
    policy = ProjectPolicy.new(users(:owner), projects(:discarded))
    assert_not policy.show?
  end
end
```

Every policy rule gets a test. Every Scope gets a test covering admin, owner, and anonymous cases.

### Background jobs

```ruby
test "enqueues sync job on link" do
  assert_enqueued_with(job: SyncHackatimeHoursJob, args: [@user.id]) do
    @user.link_hackatime!(token: "x")
  end
end
```

Use `perform_enqueued_jobs` to run jobs synchronously when testing end-state.

### Turbo Streams

```ruby
test "creating a project returns a turbo stream" do
  sign_in_as users(:regular)
  post projects_path(format: :turbo_stream), params: { project: { title: "x" } }
  assert_response :success
  assert_match "turbo-stream", response.content_type
end
```

### System tests

Use system tests only for user-visible flows that actually need a browser. Prefer controller + model coverage otherwise.

```ruby
class ShipSubmissionTest < ApplicationSystemTestCase
  test "user submits a ship" do
    sign_in_as users(:regular)
    visit new_project_path
    fill_in "Title", with: "x"
    click_on "Ship"
    assert_text "Submitted"
  end
end
```

## Assertions

Use Minitest assertions. `require "minitest/assertions"` is already loaded.

| Assertion                           | When                                                  |
|-------------------------------------|-------------------------------------------------------|
| `assert x`, `assert_not x`          | Truthiness                                            |
| `assert_equal expected, actual`     | Value equality                                        |
| `assert_includes haystack, needle`  | Collection membership                                 |
| `assert_difference 'Model.count'`   | Record-count change                                   |
| `assert_no_difference 'Model.count'`| No record-count change                                |
| `assert_enqueued_with(job: …)`      | Job enqueuing                                         |
| `assert_emails N`                   | Mailer assertions                                     |
| `assert_redirected_to path`         | Redirect check                                        |
| `assert_response :success`          | Response status                                       |

## Sorbet runtime checks in tests

`sorbet-runtime` validates `sig`-annotated methods at runtime in every environment, including test. If a test calls a typed method with the wrong type, it raises `TypeError` before any assertion runs.

- If a test needs to deliberately pass a wrong type (e.g., testing error handling for malformed input), narrow the sig with `.checked(:never)` — do not sprinkle `T.unsafe`.
- When adding a `sig` to existing code, run the full test suite. Tests that were silently passing nil or a Hash where the sig says String will now fail loudly.
- Never stub `T::Utils` or `T::Configuration` in a test. If a runtime check fires, the sig or the caller is wrong.

## Common testing issues

1. **Parallel test collisions** → Use unique identifiers; check unique indexes.
2. **Fixture N+1** → Even fixtures can trigger N+1 when `includes` is missing. Check the test log.
3. **System tests flaky** → Use `assert_text` / `assert_selector` (they wait) instead of raw `page.has_text?`.
4. **Time-dependent test** → Freeze time with `travel_to`, unfreeze with `travel_back`.
5. **Job ran during test teardown** → Use `perform_enqueued_jobs` in a block; don't leak enqueued jobs between tests.

## Systematic debugging

When multiple tests fail or an integration issue is complex:

1. **Identify root causes**:
   - Run failing tests individually to isolate.
   - Read error messages carefully. Note both the failure line and any wrapped exceptions.
   - Reproduce consistently before investigating. A flaky test is different from a broken one.
   - Check recent changes: `git log`, `git diff`.
   - When you don't know, say "I don't understand X" rather than guessing.

2. **Fix in logical order**:
   - Compilation/load errors first (bad require, undefined constant).
   - Authorization (Pundit) next.
   - Validation and business-logic errors next.
   - Race conditions and edge cases last.
   - If your first fix didn't work, STOP and re-analyze. Don't stack more fixes on a wrong hypothesis.

3. **Verify**:
   - Run the single failing test after each fix.
   - Run `bin/rubocop -f github` and `bin/brakeman --no-pager` before finishing.
   - Run the whole suite before considering the task complete (outside HCB).

## Performance testing

Use `benchmark-ips` or `benchmark/ips` for comparing implementations. For realistic load, exercise the feature in dev against Postgres with representative data — don't micro-benchmark in isolation.

## Security tests (Brakeman)

`bin/brakeman --no-pager` runs on every finish. Treat new warnings as failures for your change. Pre-existing unrelated warnings can be ignored.
