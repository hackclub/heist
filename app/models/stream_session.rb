# == Schema Information
#
# Table name: stream_sessions
#
#  id               :bigint           not null, primary key
#  actual_ends_at   :datetime
#  actual_starts_at :datetime
#  discarded_at     :datetime
#  ends_at          :datetime         not null
#  is_live          :boolean          default(FALSE), not null
#  starts_at        :datetime         not null
#  title            :string           not null
#  youtube_url      :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_stream_sessions_on_actual_starts_at  (actual_starts_at)
#  index_stream_sessions_on_discarded_at      (discarded_at)
#  index_stream_sessions_on_is_live           (is_live)
#  index_stream_sessions_on_starts_at         (starts_at)
#
class StreamSession < ApplicationRecord
  include Discardable

  has_paper_trail

  has_many :stream_appearances, dependent: :destroy
  has_many :stream_segments, dependent: :destroy

  scope :upcoming, -> { kept.where("starts_at > ?", Time.current).order(:starts_at) }
  scope :past, -> { kept.where("ends_at < ?", Time.current).order(starts_at: :desc) }
  scope :live, -> { kept.where(is_live: true) }

  validates :title, presence: true
  validates :starts_at, :ends_at, presence: true
  validates :youtube_url, format: { with: /\Ahttps?:\/\/\S+\z/i, message: "must be a valid URL starting with http:// or https://" }, allow_blank: true
  validate :ends_at_after_starts_at

  after_save :handle_live_toggle, if: :saved_change_to_is_live?

  def analytics_window
    s = actual_starts_at || starts_at
    e = actual_ends_at || ends_at
    s..e
  end

  def ships_during
    Ship.where(created_at: analytics_window)
  end

  def hours_shipped
    ships_during.approved.sum(:approved_seconds) / 3600.0
  end

  def unique_participants
    ships_during.joins(:project).distinct.count("projects.user_id")
  end

  private

  def ends_at_after_starts_at
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after starts_at") if ends_at <= starts_at
  end

  def handle_live_toggle
    if is_live
      update_columns(actual_starts_at: Time.current) if actual_starts_at.nil?
    elsif actual_ends_at.nil?
      update_columns(actual_ends_at: Time.current)
    end
    StreamService.expire_cache!(session_id: id)
  end
end
