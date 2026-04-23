# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: rsvps
#
#  id         :bigint           not null, primary key
#  email      :string           not null
#  source     :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_rsvps_on_lower_email  (lower((email)::text)) UNIQUE
#
class Rsvp < ApplicationRecord
  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }

  before_validation :normalize_email

  private

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end
end
