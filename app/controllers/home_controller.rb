# typed: true
# frozen_string_literal: true

class HomeController < ApplicationController
  extend T::Sig

  WEEKLY_HOUR_GOAL = 1_000
  DEFAULT_WEEKEND_START = "2026-05-01T17:00:00Z"

  def index
    @week_start = weekend_start
    @week_end = @week_start + 48.hours
    @week_number = current_week_number
    @seconds_shipped = shipped_seconds_since(@week_start)
    @hour_goal = WEEKLY_HOUR_GOAL
    @hours_shipped = (@seconds_shipped / 3600.0).round
    @week_ends_at = @week_end
    @user_logged_seconds = current_user.hackatime_total_seconds(start_date: @week_start.to_date, end_date: @week_end.to_date) || 0
    @user_shipped_seconds = current_user.ships.approved.sum(:approved_seconds).to_i
    @bulletin_posts = BulletinPost.published.limit(5)
    @activity = recent_activity(limit: 8)
    @projects = current_user.projects.kept.order(updated_at: :desc).limit(8)
  end

  private

  sig { returns(ActiveSupport::TimeWithZone) }
  def weekend_start
    Time.zone.parse(ENV.fetch("HEIST_WEEKEND_START", DEFAULT_WEEKEND_START))
  end

  sig { returns(Integer) }
  def current_week_number
    Integer(ENV.fetch("HEIST_WEEK_NUMBER", "1"))
  end

  sig { params(since: ActiveSupport::TimeWithZone).returns(Integer) }
  def shipped_seconds_since(since)
    Rails.cache.fetch("home/weekly_shipped_seconds/#{since.to_i}", expires_in: 60.seconds) do
      Ship.approved.where(created_at: since..).sum(:approved_seconds).to_i
    end
  end

  sig { params(limit: Integer).returns(T::Array[T.untyped]) }
  def recent_activity(limit:)
    ships = Ship.approved
                .joins(:project)
                .where(projects: { discarded_at: nil })
                .includes(project: :user)
                .order(updated_at: :desc)
                .limit(limit)
                .to_a
    projects = Project.kept
                      .includes(:user)
                      .order(created_at: :desc)
                      .limit(limit)
                      .to_a

    entries = ships.map { |s| { kind: :ship, at: s.updated_at, record: s } } +
              projects.map { |p| { kind: :project, at: p.created_at, record: p } }

    entries.sort_by { |e| -e[:at].to_i }.first(limit)
  end
end
