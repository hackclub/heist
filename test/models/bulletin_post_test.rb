# frozen_string_literal: true

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
