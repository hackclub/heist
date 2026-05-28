# frozen_string_literal: true

# Dashboard-focused demo data, layered on top of heist_demo.rb.
# - Spreads existing approved ships' updated_at across the program window
#   so the admin pace chart shows progression instead of a single spike.
# - Adds a few pending ships with old created_at to trigger the stuck-in-review banner.
# - Adds silent-cohort users (signed up <7d, no project).
#
# Idempotent. Run with: bin/rails runner db/seeds/dashboard_demo.rb

raise "refuse to run in production" if Rails.env.production?

PROGRAM_START = Time.zone.parse(ENV.fetch("HEIST_WEEKEND_START", "2026-05-01T17:00:00Z"))
PROGRAM_END   = Time.zone.parse(ENV.fetch("HEIST_PROGRAM_END",   "2026-06-12T23:59:59Z"))
NOW           = Time.current

elapsed_days = ((NOW.to_date - PROGRAM_START.to_date).to_i).clamp(1, 60)

ActiveRecord::Base.transaction do
  approved = Ship.approved.order(:id).to_a
  if approved.any?
    approved.each_with_index do |ship, i|
      # Spread approvals roughly evenly over elapsed days, with a few hours of jitter
      day_offset = (i * elapsed_days.to_f / approved.size).floor
      approved_at = PROGRAM_START + day_offset.days + ((i * 17) % 12).hours + ((i * 7) % 60).minutes
      approved_at = NOW - 5.minutes if approved_at > NOW
      ship.update_columns(updated_at: approved_at)
    end
  end

  # A few stuck pending ships
  demo_users = User.where("email LIKE ?", "demo+%@theheist.dev").includes(:projects).order(:id).limit(4).to_a
  demo_users.each_with_index do |user, idx|
    project = user.projects.first
    next unless project
    ship = Ship.find_or_initialize_by(project: project, status: :pending, justification: "stuck demo #{idx}")
    next if ship.persisted?
    ship.frozen_repo_link  = "https://github.com/the-heist-demo/stuck-#{idx}"
    ship.frozen_demo_link  = "https://stuck-#{idx}.theheist.dev"
    ship.frozen_screenshot = nil
    ship.created_at        = NOW - (26 + idx * 6).hours
    ship.save!
    ship.update_columns(created_at: NOW - (26 + idx * 6).hours)
  end

  # A past stream session so the Stream Impact panel has data
  past_start = NOW - 4.days
  past_end   = NOW - 4.days + 6.hours
  StreamSession.find_or_create_by!(title: "The Heist — Kickoff") do |s|
    s.starts_at        = past_start
    s.ends_at          = past_end
    s.actual_starts_at = past_start
    s.actual_ends_at   = past_end
  end

  # Silent cohort: recent signups with no project
  4.times do |i|
    email = "silent+#{i}@theheist.dev"
    user = User.find_or_initialize_by(email: email)
    is_new = user.new_record?
    user.assign_attributes(
      display_name: "Silent #{i + 1}",
      avatar:       "https://avatars.githubusercontent.com/u/#{2000 + i}?v=4",
      timezone:     "America/New_York",
      slack_id:     "U-SILENT-#{i}",
      hca_id:       "silent-hca-#{i}",
      roles:        [ "user" ],
    )
    user.save!
    user.update_columns(created_at: NOW - ((i + 1) * 18).hours) if is_new
  end
end

Rails.cache.delete_matched("admin_dash/*") rescue nil
Rails.cache.delete_matched("home/weekly_shipped_seconds/*") rescue nil

approved_total_seconds = Ship.approved.sum(:approved_seconds).to_i
stuck = Ship.pending.where("created_at < ?", 24.hours.ago).count
silent = User.silent_signups.count

puts "dashboard demo data seeded:"
puts "  approved ships:  #{Ship.approved.count} (#{approved_total_seconds / 3600}h total, spread across #{elapsed_days} days)"
puts "  stuck pending:   #{stuck} (>24h, no reviewer)"
puts "  silent cohort:   #{silent} users in last 7d with no project"
