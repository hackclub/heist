# frozen_string_literal: true

class HackatimeFanoutJob < ApplicationJob
  queue_as :default

  DEFAULT_WEEKEND_START = "2026-05-01T17:00:00Z"

  def perform
    week_start = Time.zone.parse(ENV.fetch("HEIST_WEEKEND_START", DEFAULT_WEEKEND_START))
    week_end = week_start + 48.hours

    User.kept
        .where.not(hackatime_token: nil)
        .where.not(hackatime_uid: nil)
        .find_each do |user|
      HackatimeRefreshJob.perform_later(user.id, week_start.iso8601, week_end.iso8601)
    end
  end
end
