# frozen_string_literal: true

require "test_helper"

class BulletinPostPolicyTest < ActiveSupport::TestCase
  def admin
    users(:one) # fixture one is admin
  end

  def regular
    users(:two)
  end

  test "admins can create/update/destroy" do
    policy = BulletinPostPolicy.new(admin, BulletinPost)
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
  end

  test "non-admin signed-in users can only read" do
    policy = BulletinPostPolicy.new(regular, BulletinPost)
    assert policy.index?
    assert policy.show?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "anonymous users see no posts" do
    scope = BulletinPostPolicy::Scope.new(nil, BulletinPost).resolve
    assert_equal 0, scope.count
  end

  test "signed-in users see only published posts via scope" do
    past = BulletinPost.create!(title: "Past", body: "b", posted_at: 1.hour.ago)
    future = BulletinPost.create!(title: "Future", body: "b", posted_at: 1.hour.from_now)

    scope_ids = BulletinPostPolicy::Scope.new(regular, BulletinPost).resolve.ids
    assert_includes scope_ids, past.id
    assert_not_includes scope_ids, future.id
  end
end
