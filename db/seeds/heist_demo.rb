# frozen_string_literal: true

# Idempotent demo data for the Heist home dashboard.
# Run with: bin/rails runner db/seeds/heist_demo.rb
#
# Creates ~30 contributors, each with 1-2 projects and 1-3 approved ships
# whose approved_seconds fan out from ~5 minutes to ~6 hours so the
# segmented progress bar shows wide visual variety.

raise "refuse to run in production" if Rails.env.production?

WEEK_START = Time.zone.parse(ENV.fetch("HEIST_WEEKEND_START", "2026-05-01T17:00:00Z"))

CONTRIBUTORS = %w[
  tessa vega byte pixel glitch cipher nyx atlas cobalt ember
  wren onyx sable quill reed slate vexa flint indigo juno
  kade lila marlow nova otis pia quincy rune saxon tully
].freeze

PROJECT_BANK = [
  [ "specter",      "A game where your last run will haunt you." ],
  [ "spotiflight",  "Boarding tickets generated from your Spotify history." ],
  [ "lockpick",     "A browser tool for cracking CSS layouts." ],
  [ "vault",        "End-to-end encrypted note locker, no server." ],
  [ "tracer",       "Visualize the network calls behind any web app." ],
  [ "breaker",      "Stress test your API with one config file." ],
  [ "dossier",      "Pull-request changelog generator for tiny teams." ],
  [ "mirror",       "Side-by-side comparison of two design systems." ],
  [ "midnight",     "A pomodoro app that punishes you with sirens." ],
  [ "ghost",        "Auto-generates fake reviewers for your draft PRs." ],
  [ "scanner",      "Find unused CSS classes across an entire repo." ],
  [ "cipher-key",   "Tiny passphrase manager for offline machines." ],
  [ "ledger",       "Budget tracker that only speaks in Hack Club $." ],
  [ "telegraph",    "Send low-bandwidth status pings to your team." ],
  [ "courier",      "Routing puzzle game with package delivery vibes." ],
  [ "pager",        "On-call rotation explainer for first-time SREs." ],
  [ "beacon",       "Lighthouse audits, but as a Discord bot." ],
  [ "signal",       "Wifi heatmap from a phone walking around a room." ],
  [ "decoy",        "Honeypot generator for indie SaaS founders." ],
  [ "alibi",        "Time-travel-style git history visualizer." ],
  [ "getaway",      "Plan a road trip from one search query." ],
  [ "syndicate",    "A leaderboard for collaborative coding sessions." ],
  [ "accomplice",   "Pair programming matchmaker for solo hackers." ],
  [ "pickpocket",   "Nicely-named clipboard manager for macOS." ],
  [ "hideout",      "Tiny wiki engine with no JavaScript on the page." ],
  [ "frequency",    "FM-radio-style RSS reader with a tuning dial." ],
  [ "blueprint",    "Sketch-to-Tailwind UI generator." ],
  [ "midnight-2",   "The sequel nobody asked for, but everybody got." ]
].freeze

# Approved-seconds buckets, ascending. Mix of small/medium/large so the bar
# has clear texture left to right.
SHIP_SIZES = [
  300, 480, 600, 720, 900, 1200, 1500, 1800, 2100, 2400,
  2700, 3000, 3300, 3600, 4200, 4800, 5400, 6000, 6600, 7200,
  7800, 8400, 9000, 9600, 10200, 10800, 12000, 13200, 14400, 15600,
  16800, 18000, 19200, 20400, 21600
].freeze

def upsert_user(slug, index)
  email = "demo+#{slug}@theheist.dev"
  User.find_or_create_by!(email: email) do |u|
    u.display_name = slug.split("-").map(&:capitalize).join(" ")
    u.avatar       = "https://avatars.githubusercontent.com/u/#{1000 + index}?v=4"
    u.timezone     = "America/New_York"
    u.slack_id     = "U-DEMO-#{slug.upcase.gsub('-', '_')}"
    u.hca_id       = "demo-hca-#{slug}"
    u.roles        = [ "user" ]
  end
end

def upsert_project(user, name, description)
  Project.find_or_create_by!(user: user, name: name) do |p|
    p.description = description
    p.tags        = []
    p.is_unlisted = false
  end
end

def create_ship(project, seconds, created_at)
  Ship.find_or_create_by!(project: project, approved_seconds: seconds, created_at: created_at) do |s|
    s.status            = :approved
    s.frozen_repo_link  = "https://github.com/the-heist-demo/#{project.name}"
    s.frozen_demo_link  = "https://#{project.name}.theheist.dev"
    s.frozen_screenshot = nil
    s.justification     = "Shipped during The Heist demo seed."
  end
end

ActiveRecord::Base.transaction do
  shipped_count = 0
  total_seconds = 0

  CONTRIBUTORS.each_with_index do |slug, i|
    user = upsert_user(slug, i)
    project_specs = PROJECT_BANK.values_at(i % PROJECT_BANK.size, (i + 7) % PROJECT_BANK.size)
                                .uniq { |(name, _)| name }
    projects = project_specs.map { |name, desc| upsert_project(user, "#{name}-#{slug[0]}", desc) }

    # 1-3 ships per user, sizes pulled across the SHIP_SIZES distribution
    ship_count = (i % 3) + 1
    ship_count.times do |k|
      seconds = SHIP_SIZES[(i * 3 + k * 5) % SHIP_SIZES.size]
      hours_offset = (i * 0.7 + k * 1.3) % 40
      created = WEEK_START + hours_offset.hours
      create_ship(projects[k % projects.size], seconds, created)
      shipped_count += 1
      total_seconds += seconds
    end
  end

  Rails.cache.delete_matched("home/weekly_shipped_seconds/*")

  puts "users:    #{User.where("email LIKE ?", "demo+%@theheist.dev").count}"
  puts "projects: #{Project.joins(:user).where(users: { email: User.where("email LIKE ?", "demo+%@theheist.dev").select(:email) }).count}"
  puts "ships:    #{shipped_count} (#{total_seconds / 3600}h #{(total_seconds % 3600) / 60}m total)"
end
