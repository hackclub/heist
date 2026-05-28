# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: bulletin_posts
#
#  id           :bigint           not null, primary key
#  body         :text             not null
#  discarded_at :datetime
#  posted_at    :datetime         not null
#  title        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  author_id    :bigint
#
# Indexes
#
#  index_bulletin_posts_on_discarded_at  (discarded_at)
#  index_bulletin_posts_on_posted_at     (posted_at)
#
# Foreign Keys
#
#  fk_rails_...  (author_id => users.id) ON DELETE => nullify
#
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
