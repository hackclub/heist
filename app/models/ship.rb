# == Schema Information
#
# Table name: ships
#
#  id                :bigint           not null, primary key
#  approved_seconds  :integer
#  claim_expires_at  :datetime
#  feedback          :text
#  frozen_demo_link  :string
#  frozen_hca_data   :text
#  frozen_repo_link  :string
#  frozen_screenshot :string
#  justification     :string
#  status            :integer          default("pending"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  project_id        :bigint           not null
#  reviewer_id       :bigint
#
# Indexes
#
#  index_ships_on_claim_expires_at  (claim_expires_at) WHERE (claim_expires_at IS NOT NULL)
#  index_ships_on_project_id        (project_id)
#  index_ships_on_reviewer_id       (reviewer_id)
#  index_ships_on_status            (status)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (reviewer_id => users.id)
#
class Ship < ApplicationRecord
  has_paper_trail

  belongs_to :project
  belongs_to :reviewer, class_name: "User", optional: true

  enum :status, { pending: 0, approved: 1, returned: 2, rejected: 3 }

  TERMINAL_STATUSES = %w[approved returned rejected].freeze
  CLAIM_DURATION = 30.minutes

  serialize :frozen_hca_data, coder: JSON
  encrypts :frozen_hca_data

  validates :status, presence: true
  validate :status_transition_allowed, if: :status_changed?

  after_update_commit :notify_status_change, if: :saved_change_to_status?

  delegate :user, to: :project

  scope :for_user, ->(user) { joins(:project).where(projects: { user_id: user.id }) }

  # Single-statement claim. Succeeds only if the ship is unclaimed, claimed by
  # the same reviewer (idempotent re-claim), or the existing claim has expired.
  # Returns true on claim, false if someone else holds an unexpired claim.
  def self.atomic_claim!(ship_id, reviewer)
    rows = where(id: ship_id)
             .where("reviewer_id IS NULL OR reviewer_id = :rid OR claim_expires_at IS NULL OR claim_expires_at < :now",
                    rid: reviewer.id, now: Time.current)
             .update_all(reviewer_id: reviewer.id, claim_expires_at: CLAIM_DURATION.from_now)
    rows.positive?
  end

  private

  # Once a ship is approved/returned/rejected, the agreed protocol is to create
  # a new Ship row rather than mutate the terminal one. Console can bypass via update_columns.
  def status_transition_allowed
    return if new_record?
    return unless TERMINAL_STATUSES.include?(status_was)
    errors.add(:status, "cannot transition from #{status_was}")
  end

  # Mail-delivery failures must never roll back an approval; log and continue.
  def notify_status_change
    MailDeliveryService.ship_status_changed(self)
  rescue StandardError => e
    Rails.logger.error("Ship#notify_status_change failed for ship #{id}: #{e.class}: #{e.message}")
  end
end
