# frozen_string_literal: true

class HackatimeRefreshJob < ApplicationJob
  queue_as :default

  CACHE_TTL = 1.hour

  def self.cache_key(user_id, week_start)
    "hackatime/user/#{user_id}/week/#{week_start.to_i}"
  end

  def perform(user_id, week_start_iso, week_end_iso)
    user = User.find_by(id: user_id)
    return unless user&.has_hackatime?

    week_start = Time.zone.parse(week_start_iso)
    week_end = Time.zone.parse(week_end_iso)

    seconds = user.hackatime_total_seconds(
      start_date: week_start.to_date,
      end_date: week_end.to_date
    )

    Rails.cache.write(self.class.cache_key(user.id, week_start), seconds.to_i, expires_in: CACHE_TTL)
  end
end
