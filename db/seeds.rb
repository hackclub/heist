# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Stream session with segments for development
next_saturday = Date.current.next_occurring(:saturday)
next_sunday = next_saturday + 1.day

session = StreamSession.find_or_create_by!(title: "The Heist — Dev Week") do |s|
  s.starts_at = next_saturday.in_time_zone("Eastern Time (US & Canada)").change(hour: 12)
  s.ends_at = next_sunday.in_time_zone("Eastern Time (US & Canada)").change(hour: 22)
end

segments = [
  { label: "Kickoff", description: "Intro, rules, and getting started", kind: :kickoff,
    starts_at: session.starts_at, ends_at: session.starts_at + 30.minutes },
  { label: "300hr milestone", description: "Check-in on progress", kind: :milestone,
    starts_at: session.starts_at + 4.hours, ends_at: session.starts_at + 4.hours + 15.minutes },
  { label: "Prize unlock — 300hrs", description: "Community unlocks the 300hr prize tier", kind: :prize_unlock,
    starts_at: session.starts_at + 6.hours, ends_at: session.starts_at + 6.hours + 15.minutes },
  { label: "Day 1 wrap", description: "Recap and shoutouts", kind: :wrap,
    starts_at: session.starts_at + 10.hours, ends_at: session.starts_at + 10.hours + 30.minutes },
  { label: "Day 2 open hacking", description: "Free-form building time", kind: :general,
    starts_at: next_sunday.in_time_zone("Eastern Time (US & Canada)").change(hour: 10),
    ends_at: next_sunday.in_time_zone("Eastern Time (US & Canada)").change(hour: 16) },
  { label: "Final push", description: "Last chance to ship", kind: :milestone,
    starts_at: next_sunday.in_time_zone("Eastern Time (US & Canada)").change(hour: 18),
    ends_at: next_sunday.in_time_zone("Eastern Time (US & Canada)").change(hour: 18, min: 15) },
  { label: "Grand finale", description: "Winners and wrap-up", kind: :wrap,
    starts_at: next_sunday.in_time_zone("Eastern Time (US & Canada)").change(hour: 21),
    ends_at: next_sunday.in_time_zone("Eastern Time (US & Canada)").change(hour: 22) }
]

segments.each do |attrs|
  StreamSegment.find_or_create_by!(stream_session: session, label: attrs[:label]) do |seg|
    seg.assign_attributes(attrs.except(:label))
  end
end
