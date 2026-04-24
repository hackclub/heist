# typed: true
# frozen_string_literal: true

class HeistSchedule
  extend T::Sig

  Entry = Data.define(:label, :starts_at, :ends_at, :kind) do
    extend T::Sig

    sig { returns(String) }
    def time_range
      "#{format_time(starts_at)} - #{format_time(ends_at)}"
    end

    sig { returns(String) }
    def hour_label
      starts_at.strftime("%-l%p")
    end

    sig { returns(Integer) }
    def duration_minutes
      ((ends_at - starts_at) / 60).to_i
    end

    private

    sig { params(time: Time).returns(String) }
    def format_time(time)
      time.strftime("%-l:%M %p")
    end
  end

  PLACEHOLDER = T.let(
    [
      Entry.new(label: "Stream starts", starts_at: Time.zone.local(2026, 5, 2, 7, 0),  ends_at: Time.zone.local(2026, 5, 2, 7, 15),  kind: "kickoff"),
      Entry.new(label: "Lock in hour",  starts_at: Time.zone.local(2026, 5, 2, 7, 15), ends_at: Time.zone.local(2026, 5, 2, 8, 15),  kind: "general"),
      Entry.new(label: "Giveaway!",     starts_at: Time.zone.local(2026, 5, 2, 8, 15), ends_at: Time.zone.local(2026, 5, 2, 8, 30),  kind: "prize_unlock"),
      Entry.new(label: "Lock in hour",  starts_at: Time.zone.local(2026, 5, 2, 8, 30), ends_at: Time.zone.local(2026, 5, 2, 9, 30),  kind: "general"),
      Entry.new(label: "Title",         starts_at: Time.zone.local(2026, 5, 2, 9, 30), ends_at: Time.zone.local(2026, 5, 2, 10, 30), kind: "milestone"),

      Entry.new(label: "Lock in hour",  starts_at: Time.zone.local(2026, 5, 3, 7, 0),  ends_at: Time.zone.local(2026, 5, 3, 7, 15),  kind: "general"),
      Entry.new(label: "Lock in hour",  starts_at: Time.zone.local(2026, 5, 3, 7, 15), ends_at: Time.zone.local(2026, 5, 3, 8, 15),  kind: "general"),
      Entry.new(label: "Giveaway!",     starts_at: Time.zone.local(2026, 5, 3, 8, 15), ends_at: Time.zone.local(2026, 5, 3, 8, 30),  kind: "prize_unlock"),
      Entry.new(label: "Lock in hour",  starts_at: Time.zone.local(2026, 5, 3, 8, 30), ends_at: Time.zone.local(2026, 5, 3, 9, 30),  kind: "general"),
      Entry.new(label: "Title",         starts_at: Time.zone.local(2026, 5, 3, 9, 30), ends_at: Time.zone.local(2026, 5, 3, 10, 30), kind: "milestone")
    ].freeze,
    T::Array[Entry]
  )

  SATURDAY_DATE = T.let(Date.new(2026, 5, 2), Date)
  SUNDAY_DATE   = T.let(Date.new(2026, 5, 3), Date)

  SlotRow = Data.define(:time_of_day, :saturday_entry, :sunday_entry, :hour_label) do
    extend T::Sig

    sig { returns(Integer) }
    def hour
      canonical_entry.starts_at.hour
    end

    sig { returns(Entry) }
    def canonical_entry
      saturday_entry || T.must(sunday_entry)
    end
  end

  CurrentMarker = Data.define(:time_of_day, :label)

  sig { returns(T::Array[Entry]) }
  def self.saturday
    entries.select { |e| e.starts_at.to_date == SATURDAY_DATE }
  end

  sig { returns(T::Array[Entry]) }
  def self.sunday
    entries.select { |e| e.starts_at.to_date == SUNDAY_DATE }
  end

  sig { returns(T::Array[Entry]) }
  def self.entries
    PLACEHOLDER
  end

  sig { returns(T::Array[SlotRow]) }
  def self.slot_rows
    sat_by_key = saturday.index_by { |e| time_key(e) }
    sun_by_key = sunday.index_by { |e| time_key(e) }
    keys = (sat_by_key.keys | sun_by_key.keys).sort

    previous_hour = T.let(nil, T.nilable(Integer))
    keys.map do |key|
      sat = sat_by_key[key]
      sun = sun_by_key[key]
      canonical = T.must(sat || sun)
      hour = canonical.starts_at.hour
      label = hour == previous_hour ? nil : canonical.hour_label
      previous_hour = hour
      SlotRow.new(time_of_day: key, saturday_entry: sat, sunday_entry: sun, hour_label: label)
    end
  end

  sig { returns(T.nilable(CurrentMarker)) }
  def self.current_marker
    CurrentMarker.new(time_of_day: "08:15", label: "8:22")
  end

  sig { params(entry: Entry).returns(String) }
  def self.time_key(entry)
    entry.starts_at.strftime("%H:%M")
  end
end
