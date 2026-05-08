class Admin::StaticPagesController < Admin::ApplicationController
  HOUR_GOAL = 1_000
  DEFAULT_PROGRAM_START = "2026-05-01T17:00:00Z"
  DEFAULT_PROGRAM_END = "2026-06-12T23:59:59Z"
  STUCK_REVIEW_THRESHOLD = 24.hours
  PACE_CACHE_TTL = 60.seconds

  def index
    @now = Time.current
    @program_start = program_start
    @program_end = program_end
    @hour_goal = HOUR_GOAL

    load_pace
    load_kpis
    load_funnel
    load_banners
    load_leaderboard
    load_silent_cohort
    load_recent_activity
    load_leading_indicators
    load_movers
    load_stream_impact
  end

  private

  def program_start
    Time.zone.parse(ENV.fetch("HEIST_WEEKEND_START", DEFAULT_PROGRAM_START))
  end

  def program_end
    Time.zone.parse(ENV.fetch("HEIST_PROGRAM_END", DEFAULT_PROGRAM_END))
  end

  def load_pace
    series = Rails.cache.fetch("admin_dash/pace_series_v1", expires_in: PACE_CACHE_TTL) do
      compute_pace_series
    end

    @pace_points = series[:points]
    @approved_seconds = series[:total_seconds]
    @approved_hours = (@approved_seconds / 3600.0).round(1)
    @progress_pct = pct(@approved_seconds, HOUR_GOAL * 3600)

    elapsed = elapsed_program_pct
    @expected_hours = (HOUR_GOAL * elapsed / 100.0).round(1)
    @expected_pct = elapsed
    @hours_delta = (@approved_hours - @expected_hours).round(1)

    elapsed_days = days_elapsed
    if elapsed_days >= 0.5
      rate_per_day = @approved_hours / elapsed_days
      @projection_hours = (rate_per_day * total_days).round(0)
    else
      @projection_hours = nil
    end
    @projection_delta = @projection_hours ? (@projection_hours - HOUR_GOAL) : nil

    build_chart_arrays
  end

  def build_chart_arrays
    total_day_count = (@program_end.to_date - @program_start.to_date).to_i
    @chart_total_days = total_day_count

    @chart_labels = (0..total_day_count).map { |i| (@program_start.to_date + i.days).strftime("%b %-d") }

    hours_by_idx = @pace_points.each_with_object({}) { |p, h| h[p[:day_index]] = p[:cumulative_hours] }
    @chart_actual = (0..total_day_count).map { |i| hours_by_idx[i] }

    @chart_today_index = @pace_points.last&.dig(:day_index) || 0
  end

  def compute_pace_series
    seconds_by_day = Ship.approved
                         .where(updated_at: @program_start..@now)
                         .group("DATE(updated_at)")
                         .sum(:approved_seconds)
                         .transform_keys { |k| k.is_a?(Date) ? k : Date.parse(k.to_s) }

    end_day = [ @now.to_date, @program_end.to_date ].min
    days = (@program_start.to_date..end_day).to_a

    running = 0
    points = days.each_with_index.map do |date, idx|
      running += (seconds_by_day[date] || 0)
      { day_index: idx, date: date, cumulative_hours: (running / 3600.0).round(2) }
    end

    { points: points, total_seconds: running }
  end

  def days_elapsed
    [ ((@now - @program_start) / 1.day).to_f, 0.0 ].max
  end

  def total_days
    days = ((@program_end - @program_start) / 1.day).to_f
    days.positive? ? days : 1.0
  end

  def elapsed_program_pct
    return 0 if total_days <= 0
    (days_elapsed / total_days * 100).clamp(0, 100).round(1)
  end

  def pct(num, denom)
    return 0 if denom.to_f.zero?
    ((num.to_f / denom) * 100).clamp(0, 100).round(1)
  end

  def load_kpis
    today_start = @now.beginning_of_day
    seven_days_ago = (@now - 7.days).beginning_of_day
    fourteen_days_ago = (@now - 14.days).beginning_of_day

    hours_7d = Ship.approved.where(updated_at: seven_days_ago..@now).sum(:approved_seconds) / 3600.0
    hours_prev_7d = Ship.approved.where(updated_at: fourteen_days_ago..seven_days_ago).sum(:approved_seconds) / 3600.0

    signups_today = User.kept.where(created_at: today_start..@now).count
    signups_7d = User.kept.where(created_at: seven_days_ago..today_start).count
    avg_signups = signups_7d / 7.0

    hackatime_count = User.kept.where.not(hackatime_token: nil).where.not(hackatime_uid: nil).count
    total_users = User.kept.count
    hackatime_pct_value = pct(hackatime_count, total_users)

    pending_count = Ship.pending.count
    stuck_count = Ship.pending.where("created_at < ?", STUCK_REVIEW_THRESHOLD.ago).count

    seconds_by_day = Ship.approved.where(updated_at: fourteen_days_ago..@now)
                         .group("DATE(updated_at)").sum(:approved_seconds)
                         .transform_keys { |k| k.is_a?(Date) ? k : Date.parse(k.to_s) }
    signups_by_day = User.kept.where(created_at: fourteen_days_ago..@now)
                         .group("DATE(created_at)").count
                         .transform_keys { |k| k.is_a?(Date) ? k : Date.parse(k.to_s) }
    new_ships_by_day = Ship.where(created_at: fourteen_days_ago..@now)
                           .group("DATE(created_at)").count
                           .transform_keys { |k| k.is_a?(Date) ? k : Date.parse(k.to_s) }

    last_14_days = ((@now.to_date - 13.days)..@now.to_date).to_a

    @kpis = [
      {
        label: "Hours · last 7d",
        value: hours_7d.round(1),
        unit: "h",
        sparkline: last_14_days.map { |d| (seconds_by_day[d] || 0) / 3600.0 },
        delta_label: hours_delta_label(hours_7d, hours_prev_7d),
        delta_positive: hours_7d >= hours_prev_7d,
        accent: false,
        link: nil
      },
      {
        label: "Signups · today",
        value: signups_today,
        unit: "",
        sparkline: last_14_days.map { |d| signups_by_day[d] || 0 },
        delta_label: avg_signups.zero? ? "no 7d baseline" : "vs #{avg_signups.round(1)}/day avg",
        delta_positive: signups_today >= avg_signups,
        accent: false,
        link: admin_users_path
      },
      {
        label: "Hackatime linked",
        value: hackatime_count,
        unit: "",
        sparkline: nil,
        delta_label: "#{hackatime_pct_value}% of users",
        delta_positive: hackatime_pct_value >= 50,
        accent: false,
        link: nil
      },
      {
        label: "Ships in review",
        value: pending_count,
        unit: "",
        sparkline: last_14_days.map { |d| new_ships_by_day[d] || 0 },
        delta_label: stuck_count.positive? ? "#{stuck_count} stuck > 24h" : "queue healthy",
        delta_positive: stuck_count.zero?,
        accent: stuck_count.positive?,
        link: admin_ships_path(status: "pending")
      }
    ]
  end

  def hours_delta_label(curr, prev)
    return "no prior baseline" if prev.zero?
    delta_pct = ((curr - prev) / prev * 100).round
    sign = delta_pct >= 0 ? "+" : ""
    "#{sign}#{delta_pct}% vs prior 7d"
  end

  def load_funnel
    total = User.kept.count
    linked = User.kept.where.not(hackatime_token: nil).where.not(hackatime_uid: nil).count
    has_project = Project.kept.distinct.count(:user_id)
    has_ship = User.kept.joins(projects: :ships).distinct.count
    has_approved = User.kept.joins(projects: :ships).where(ships: { status: :approved }).distinct.count

    stages = [
      { label: "Signed up", count: total, link: admin_users_path },
      { label: "Linked Hackatime", count: linked, link: nil },
      { label: "Created project", count: has_project, link: admin_projects_path },
      { label: "Submitted ship", count: has_ship, link: admin_ships_path },
      { label: "Got approved", count: has_approved, link: admin_ships_path(status: "approved") }
    ]

    stages.each_with_index do |s, i|
      prev_count = i.zero? ? total : stages[i - 1][:count]
      s[:from_prev_pct] = i.zero? ? nil : pct(s[:count], prev_count)
      s[:from_top_pct] = pct(s[:count], total)
      s[:width_pct] = total.zero? ? 0 : (s[:count].to_f / total * 100).clamp(0, 100).round(1)
    end

    if total.positive?
      tail = stages[1..]
      worst = tail.min_by { |s| s[:from_prev_pct] || 100 }
      worst[:worst] = true if worst && worst[:from_prev_pct] && worst[:from_prev_pct] < 100
    end

    @funnel_stages = stages
  end

  def load_banners
    banners = []

    stuck = Ship.pending.where("created_at < ?", STUCK_REVIEW_THRESHOLD.ago).count
    if stuck.positive?
      banners << {
        kind: :alert,
        text: "#{stuck} #{"ship".pluralize(stuck)} stuck in review > 24h",
        link: admin_ships_path(status: "pending"),
        cta: "open queue →"
      }
    end

    silent = silent_user_scope.count
    if silent.positive?
      banners << {
        kind: :warn,
        text: "#{silent} #{"user".pluralize(silent)} signed up in last 7d with no project",
        link: admin_users_path,
        cta: "review users →"
      }
    end

    if @now > @program_start && @hours_delta < -10
      banners << {
        kind: :alert,
        text: "Off pace: #{@hours_delta.abs.round(1)}h behind expected (#{@expected_hours.round(0)}h target so far)",
        link: nil,
        cta: nil
      }
    elsif @hours_delta > 10
      banners << {
        kind: :ok,
        text: "Ahead of pace: +#{@hours_delta.round(1)}h vs expected",
        link: nil,
        cta: nil
      }
    end

    @banners = banners
  end

  def load_leaderboard
    rows = User.kept
               .joins(projects: :ships)
               .where(ships: { status: :approved })
               .group("users.id")
               .order(Arel.sql("SUM(ships.approved_seconds) DESC"))
               .limit(8)
               .pluck(
                 "users.id",
                 "users.display_name",
                 "users.avatar",
                 Arel.sql("COUNT(DISTINCT projects.id)"),
                 Arel.sql("SUM(ships.approved_seconds)")
               )

    if rows.empty?
      @leaderboard = []
      return
    end

    user_ids = rows.map(&:first)
    last_active_by_uid = Ship.joins(:project)
                             .where(projects: { user_id: user_ids })
                             .group("projects.user_id")
                             .maximum(:updated_at)

    @leaderboard = rows.map do |uid, name, avatar, project_count, seconds|
      {
        user_id: uid,
        display_name: name,
        avatar: avatar,
        project_count: project_count,
        approved_seconds: seconds.to_i,
        approved_hours: (seconds.to_i / 3600.0).round(1),
        last_active: last_active_by_uid[uid]
      }
    end
  end

  def silent_user_scope
    User.silent_signups
  end

  def load_silent_cohort
    rows = silent_user_scope
             .order(created_at: :desc)
             .limit(8)
             .pluck(:id, :display_name, :avatar, :created_at, :hackatime_uid)

    @silent_users = rows.map do |id, name, avatar, created_at, hackatime_uid|
      {
        user_id: id,
        display_name: name.presence || "User ##{id}",
        avatar: avatar,
        created_at: created_at,
        hackatime_linked: hackatime_uid.present?
      }
    end
  end

  def load_recent_activity
    @recent_activity = Ship.where(updated_at: 24.hours.ago..)
                           .where.not(status: :pending)
                           .joins(:project)
                           .where(projects: { discarded_at: nil })
                           .order(updated_at: :desc)
                           .limit(8)
                           .includes(project: :user)
  end

  def load_leading_indicators
    total_users = User.kept.count
    linked_users = User.kept.where.not(hackatime_token: nil).where.not(hackatime_uid: nil).count

    avg_review_seconds = Ship.where.not(reviewer_id: nil)
                             .where(status: [ Ship.statuses[:approved], Ship.statuses[:returned], Ship.statuses[:rejected] ])
                             .where(updated_at: 7.days.ago..)
                             .pick(Arel.sql("AVG(EXTRACT(EPOCH FROM (updated_at - created_at)))"))
                             .to_f

    active_reviewers = Ship.where(updated_at: 7.days.ago..)
                           .where.not(reviewer_id: nil)
                           .distinct
                           .count(:reviewer_id)

    @leading = [
      {
        label: "Hackatime link rate",
        value: "#{pct(linked_users, total_users)}%",
        sub: "#{linked_users} of #{total_users} users"
      },
      {
        label: "Avg review time · 7d",
        value: avg_review_seconds.zero? ? "—" : format_duration(avg_review_seconds),
        sub: avg_review_seconds.zero? ? "no recent reviews" : "submit → decision"
      },
      {
        label: "Active reviewers · 7d",
        value: active_reviewers.to_s,
        sub: "made ≥ 1 decision"
      }
    ]
  end

  def load_movers
    seven_days_ago = (@now - 7.days).beginning_of_day
    fourteen_days_ago = (@now - 14.days).beginning_of_day

    curr = Ship.approved.joins(:project).where(projects: { discarded_at: nil })
               .where(updated_at: seven_days_ago..@now)
               .group("projects.user_id").sum(:approved_seconds)
    prev = Ship.approved.joins(:project).where(projects: { discarded_at: nil })
               .where(updated_at: fourteen_days_ago..seven_days_ago)
               .group("projects.user_id").sum(:approved_seconds)

    user_ids = (curr.keys | prev.keys).reject(&:nil?)
    if user_ids.empty?
      @movers = []
      return
    end

    name_avatar_by_uid = User.kept.where(id: user_ids).pluck(:id, :display_name, :avatar)
                             .each_with_object({}) { |(id, name, avatar), h| h[id] = [ name, avatar ] }

    rows = user_ids.map do |uid|
      curr_h = (curr[uid] || 0) / 3600.0
      prev_h = (prev[uid] || 0) / 3600.0
      delta = curr_h - prev_h
      next nil unless name_avatar_by_uid[uid]
      name, avatar = name_avatar_by_uid[uid]
      {
        user_id: uid,
        display_name: name,
        avatar: avatar,
        curr_hours: curr_h.round(1),
        prev_hours: prev_h.round(1),
        delta_hours: delta.round(1)
      }
    end.compact

    @movers = rows.sort_by { |r| -r[:delta_hours] }.first(5)
  end

  def load_stream_impact
    sessions = StreamSession.past.limit(6).to_a
    @stream_impact = sessions.map do |s|
      {
        id: s.id,
        title: s.title,
        starts_at: s.actual_starts_at || s.starts_at,
        hours_shipped: s.hours_shipped.round(1),
        unique_participants: s.unique_participants
      }
    end
  end

  def format_duration(seconds)
    s = seconds.to_i
    return "#{s}s" if s < 60
    return "#{(s / 60.0).round(1)}m" if s < 3600
    return "#{(s / 3600.0).round(1)}h" if s < 86_400
    "#{(s / 86_400.0).round(1)}d"
  end
end
