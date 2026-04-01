module StreamService
  CACHE_KEY_LIVE = "stream/live"
  CACHE_KEY_CURRENT_SESSION = "stream/current_session"

  module_function

  def current_session
    Rails.cache.fetch(CACHE_KEY_CURRENT_SESSION, expires_in: 60.seconds) do
      live_session = StreamSession.kept.live.first
      next live_session if live_session

      now = Time.current
      active_session = StreamSession.kept.where("starts_at <= ? AND ends_at >= ?", now, now).first
      next active_session if active_session

      StreamSession.upcoming.first
    end
  rescue StandardError => e
    Rails.logger.error("StreamService current_session error: #{e.class}: #{e.message}")
    nil
  end

  def live?
    Rails.cache.fetch(CACHE_KEY_LIVE, expires_in: 30.seconds) do
      StreamSession.kept.live.exists?
    end
  rescue StandardError => e
    Rails.logger.error("StreamService live? error: #{e.class}: #{e.message}")
    false
  end

  def current_segment(session)
    return nil if session.nil?

    now = Time.current
    session.stream_segments.where("starts_at <= ? AND ends_at >= ?", now, now).ordered.first
  rescue StandardError => e
    Rails.logger.error("StreamService current_segment error: #{e.class}: #{e.message}")
    nil
  end

  def schedule_for(session)
    return [] if session.nil?

    session.stream_segments.ordered.group_by { |s| s.starts_at.to_date }.map do |date, segments|
      { date: date.strftime("%A, %B %-d"), segments: segments }
    end
  rescue StandardError => e
    Rails.logger.error("StreamService schedule_for error: #{e.class}: #{e.message}")
    []
  end

  def upcoming_sessions(limit: 3)
    StreamSession.upcoming.limit(limit)
  rescue StandardError => e
    Rails.logger.error("StreamService upcoming_sessions error: #{e.class}: #{e.message}")
    []
  end

  def stats_for(session)
    return nil if session.nil?

    Rails.cache.fetch("stream/stats/#{session.id}", expires_in: 30.seconds) do
      {
        ships_count: session.ships_during.count,
        approved_ships_count: session.ships_during.approved.count,
        hours_shipped: session.hours_shipped,
        unique_participants: session.unique_participants
      }
    end
  rescue StandardError => e
    Rails.logger.error("StreamService stats_for error: #{e.class}: #{e.message}")
    nil
  end

  def expire_cache!(session_id: nil)
    Rails.cache.delete(CACHE_KEY_LIVE)
    Rails.cache.delete(CACHE_KEY_CURRENT_SESSION)
    Rails.cache.delete("stream/stats/#{session_id}") if session_id
  rescue StandardError => e
    Rails.logger.error("StreamService expire_cache! error: #{e.class}: #{e.message}")
  end
end
