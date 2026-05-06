# frozen_string_literal: true

require "test_helper"

class HackatimeRefreshJobTest < ActiveJob::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  def with_hackatime_total(seconds)
    original = HackatimeService.method(:fetch_total_seconds)
    HackatimeService.define_singleton_method(:fetch_total_seconds) { |*_, **_| seconds }
    yield
  ensure
    HackatimeService.define_singleton_method(:fetch_total_seconds, original)
  end

  test "writes per-user weekly seconds to cache for a linked user" do
    user = users(:two)
    user.update_columns(hackatime_token: "tok", hackatime_uid: "uid")
    week_start = Time.zone.parse("2026-05-01T17:00:00Z")
    week_end = week_start + 48.hours

    with_hackatime_total(7200) do
      HackatimeRefreshJob.new.perform(user.id, week_start.iso8601, week_end.iso8601)
    end

    assert_equal 7200, Rails.cache.read(HackatimeRefreshJob.cache_key(user.id, week_start))
  end

  test "no-ops for a user without Hackatime linked" do
    user = users(:two)
    user.update_columns(hackatime_token: nil, hackatime_uid: nil)
    week_start = Time.zone.parse("2026-05-01T17:00:00Z")

    HackatimeRefreshJob.new.perform(user.id, week_start.iso8601, (week_start + 48.hours).iso8601)

    assert_nil Rails.cache.read(HackatimeRefreshJob.cache_key(user.id, week_start))
  end

  test "no-ops for a missing user" do
    week_start = Time.zone.parse("2026-05-01T17:00:00Z")

    assert_nothing_raised do
      HackatimeRefreshJob.new.perform(0, week_start.iso8601, (week_start + 48.hours).iso8601)
    end
  end
end
