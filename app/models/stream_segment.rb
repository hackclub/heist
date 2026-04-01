# == Schema Information
#
# Table name: stream_segments
#
#  id                :bigint           not null, primary key
#  description       :text
#  discarded_at      :datetime
#  ends_at           :datetime         not null
#  kind              :integer          default("general"), not null
#  label             :string           not null
#  starts_at         :datetime         not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  stream_session_id :bigint           not null
#
# Indexes
#
#  index_stream_segments_on_discarded_at                     (discarded_at)
#  index_stream_segments_on_stream_session_id                (stream_session_id)
#  index_stream_segments_on_stream_session_id_and_starts_at  (stream_session_id,starts_at)
#
# Foreign Keys
#
#  fk_rails_...  (stream_session_id => stream_sessions.id)
#
class StreamSegment < ApplicationRecord
  include Discardable

  has_paper_trail

  belongs_to :stream_session

  enum :kind, { general: 0, kickoff: 1, milestone: 2, prize_unlock: 3, wrap: 4 }

  scope :ordered, -> { order(:starts_at) }

  validates :label, :starts_at, :ends_at, presence: true
  validate :ends_at_after_starts_at

  def ships_during
    Ship.where(created_at: starts_at..ends_at)
  end

  def ships_count
    ships_during.count
  end

  private

  def ends_at_after_starts_at
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after starts_at") if ends_at <= starts_at
  end
end
