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
    @user_logged_seconds = cached_hackatime_seconds(current_user, @week_start, @week_end)
    @user_shipped_seconds = current_user.ships.approved.sum(:approved_seconds).to_i
    @bulletin_posts = BulletinPost.published.limit(5)
    @activity = recent_activity(limit: 8)
    @projects = current_user.projects.kept.order(updated_at: :desc).limit(8).to_a
    @project_shipped_seconds = Ship.approved
                                   .where(project_id: @projects.map(&:id))
                                   .group(:project_id)
                                   .sum(:approved_seconds)
    @ship_segments = build_ship_segments(@week_start, @hour_goal * 3600)
  end

  private

  SegmentRow = T.type_alias { T::Hash[Symbol, T.untyped] }

  sig { params(week_start: ActiveSupport::TimeWithZone, hour_goal_seconds: Integer).returns(T::Array[SegmentRow]) }
  def build_ship_segments(week_start, hour_goal_seconds)
    ships = Ship.approved
                .joins(:project)
                .where(projects: { discarded_at: nil })
                .where(created_at: week_start..)
                .where("approved_seconds >= ?", 60)
                .order(approved_seconds: :asc)
                .includes(project: :user)
                .to_a
    return [] if ships.empty?

    user_ids = ships.map { |s| T.must(s.project).user_id }.uniq
    project_counts = Project.kept.where(user_id: user_ids).group(:user_id).count
    shipped_totals = Ship.approved
                         .joins(:project)
                         .where(projects: { user_id: user_ids })
                         .group("projects.user_id")
                         .sum(:approved_seconds)
    projects_by_uid = Project.kept
                             .where(user_id: user_ids)
                             .order(updated_at: :desc)
                             .group_by(&:user_id)

    cursor = 0.0
    ships.map do |ship|
      project = T.must(ship.project)
      seconds = ship.approved_seconds.to_i
      width_pct = hour_goal_seconds.positive? ? (seconds.to_f / hour_goal_seconds * 100.0) : 0.0
      uid = project.user_id
      row = {
        ship: ship,
        project: project,
        user: project.user,
        ship_seconds: seconds,
        offset_pct: cursor,
        width_pct: width_pct,
        user_project_count: project_counts[uid].to_i,
        user_total_shipped_seconds: shipped_totals[uid].to_i,
        user_recent_projects: (projects_by_uid[uid] || []).first(2)
      }
      cursor += width_pct
      row
    end
  end

  sig { returns(ActiveSupport::TimeWithZone) }
  def weekend_start
    Time.zone.parse(ENV.fetch("HEIST_WEEKEND_START", DEFAULT_WEEKEND_START))
  end

  sig { returns(Integer) }
  def current_week_number
    Integer(ENV.fetch("HEIST_WEEK_NUMBER", "1"))
  end

  sig { params(user: User, week_start: ActiveSupport::TimeWithZone, week_end: ActiveSupport::TimeWithZone).returns(Integer) }
  def cached_hackatime_seconds(user, week_start, week_end)
    return 0 unless user.has_hackatime?

    cached = Rails.cache.read(HackatimeRefreshJob.cache_key(user.id, week_start))
    return cached.to_i if cached

    HackatimeRefreshJob.perform_later(user.id, week_start.iso8601, week_end.iso8601)
    0
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
                .order(updated_at: :desc)
                .limit(limit)
                .to_a
    projects = Project.kept
                      .order(created_at: :desc)
                      .limit(limit)
                      .to_a

    entries = ships.map { |s| { kind: :ship, at: s.updated_at, record: s } } +
              projects.map { |p| { kind: :project, at: p.created_at, record: p } }

    top = entries.sort_by { |e| -e[:at].to_i }.first(limit)

    top_ships = top.filter_map { |e| e[:record] if e[:kind] == :ship }
    top_projects = top.filter_map { |e| e[:record] if e[:kind] == :project }

    ActiveRecord::Associations::Preloader.new(records: top_ships, associations: { project: :user }).call if top_ships.any?
    ActiveRecord::Associations::Preloader.new(records: top_projects, associations: :user).call if top_projects.any?

    top
  end
end
