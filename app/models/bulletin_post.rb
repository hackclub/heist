# typed: false
# frozen_string_literal: true

class BulletinPost < ApplicationRecord
  include Discardable

  has_paper_trail

  belongs_to :author, class_name: "User", optional: true

  validates :title, :body, :posted_at, presence: true

  scope :published, -> { kept.where("posted_at <= ?", Time.current).order(posted_at: :desc) }

  before_validation :default_posted_at

  private

  def default_posted_at
    self.posted_at ||= Time.current
  end
end
