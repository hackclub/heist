# typed: true
# frozen_string_literal: true

class LandingController < ApplicationController
  extend T::Sig

  DEFAULT_STREAM_START = "2026-05-02T17:00:00Z"
  ACTIVE_WINDOW = 15.minutes

  allow_unauthenticated_access only: %i[index]

  def index
    if user_signed_in?
      redirect_to home_path
      return
    end

    @active_hackers = active_hackers_count
    @stream_starts_at = stream_starts_at
    @stream_embed_url = ENV.fetch("HEIST_STREAM_EMBED_URL", nil)
    @stream_live = @stream_embed_url.present? && Time.current >= @stream_starts_at
  end

  private

  sig { returns(Integer) }
  def active_hackers_count
    Rails.cache.fetch("landing/active_hackers_count", expires_in: 60.seconds) do
      User.kept
          .where.not(hackatime_uid: nil)
          .where(updated_at: ACTIVE_WINDOW.ago..)
          .count
    end
  end

  sig { returns(ActiveSupport::TimeWithZone) }
  def stream_starts_at
    Time.zone.parse(ENV.fetch("HEIST_STREAM_STARTS_AT", DEFAULT_STREAM_START))
  end
end
