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
require "test_helper"

class BulletinPostTest < ActiveSupport::TestCase
  test "validates presence of title, body, posted_at" do
    post = BulletinPost.new
    post.posted_at = nil
    assert_not post.valid?
    assert_includes post.errors[:title], "can't be blank"
    assert_includes post.errors[:body], "can't be blank"
  end

  test "defaults posted_at to now when not set" do
    post = BulletinPost.new(title: "Hi", body: "Body")
    assert post.valid?
    assert_in_delta Time.current.to_i, post.posted_at.to_i, 5
  end

  test "published scope excludes future posts and discarded posts" do
    now = Time.current
    past = BulletinPost.create!(title: "Past", body: "b", posted_at: now - 1.hour)
    future = BulletinPost.create!(title: "Future", body: "b", posted_at: now + 1.hour)
    discarded = BulletinPost.create!(title: "Gone", body: "b", posted_at: now - 2.hours)
    discarded.discard

    published_ids = BulletinPost.published.ids
    assert_includes published_ids, past.id
    assert_not_includes published_ids, future.id
    assert_not_includes published_ids, discarded.id
  end
end
