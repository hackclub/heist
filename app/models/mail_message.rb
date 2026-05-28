# frozen_string_literal: true

# == Schema Information
#
# Table name: mail_messages
#
#  id            :bigint           not null, primary key
#  body          :text
#  discarded_at  :datetime
#  kind          :string           not null
#  mailable_type :string
#  read_at       :datetime
#  subject       :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  mailable_id   :bigint
#  user_id       :bigint           not null
#
# Indexes
#
#  index_mail_messages_on_discarded_at                   (discarded_at)
#  index_mail_messages_on_mailable_type_and_mailable_id  (mailable_type,mailable_id)
#  index_mail_messages_on_user_id                        (user_id)
#  index_mail_messages_unread_per_user                   (user_id,read_at) WHERE (read_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
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
