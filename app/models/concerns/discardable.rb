module Discardable
  extend ActiveSupport::Concern

  included do
    scope :kept, -> { where(discarded_at: nil) }
    scope :discarded, -> { where.not(discarded_at: nil) }
  end

  # Bypass model validations: stale or malformed data on unrelated columns
  # must never make a record un-deletable.
  def discard
    update_columns(discarded_at: Time.current)
  end

  def undiscard
    update_columns(discarded_at: nil)
  end

  def discarded?
    discarded_at.present?
  end
end
