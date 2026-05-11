# == Schema Information
#
# Table name: projects
#
#  id           :bigint           not null, primary key
#  demo_link    :string
#  description  :text
#  discarded_at :datetime
#  is_unlisted  :boolean          default(TRUE), not null
#  name         :string           not null
#  readme_link  :string
#  repo_link    :string
#  tags         :string           default([]), not null, is an Array
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_projects_on_discarded_at  (discarded_at)
#  index_projects_on_is_unlisted   (is_unlisted)
#  index_projects_on_tags          (tags) USING gin
#  index_projects_on_user_id       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Project < ApplicationRecord
  include Discardable
  include PgSearch::Model

  has_paper_trail

  pg_search_scope :search, against: [ :name, :description ], using: { tsearch: { prefix: true } }

  belongs_to :user
  has_many :ships, dependent: :destroy
  has_one_attached :banner_image

  BANNER_IMAGE_MAX_BYTES = 5.megabytes
  BANNER_IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/heic image/heif image/webp].freeze
  URL_FORMAT = /\Ahttps?:\/\/\S+\z/i

  validates :name, presence: true
  validates :is_unlisted, inclusion: { in: [ true, false ] }
  validates :demo_link, format: { with: URL_FORMAT, message: "must be a valid URL starting with http:// or https://" }, allow_blank: true
  validates :repo_link, format: { with: URL_FORMAT, message: "must be a valid URL starting with http:// or https://" }, allow_blank: true
  validates :readme_link, format: { with: URL_FORMAT, message: "must be a valid URL starting with http:// or https://" }, allow_blank: true
  validate :acceptable_banner_image

  scope :listed, -> { where(is_unlisted: false) }

  private

  def acceptable_banner_image
    return unless banner_image.attached?

    if banner_image.byte_size > BANNER_IMAGE_MAX_BYTES
      errors.add(:banner_image, "must be 5 MB or smaller")
    end

    unless BANNER_IMAGE_CONTENT_TYPES.include?(banner_image.content_type)
      errors.add(:banner_image, "must be a PNG, JPG, HEIC, or WEBP")
    end
  end
end
