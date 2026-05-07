# frozen_string_literal: true

class MailMessage < ApplicationRecord
  include Discardable

  belongs_to :user
  belongs_to :mailable, polymorphic: true, optional: true

  validates :subject, presence: true
  validates :kind, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :for_user, ->(user) { where(user: user) }

  def read?
    read_at.present?
  end

  def mark_read!
    return if read_at.present?
    update_columns(read_at: Time.current)
  end
end
