# frozen_string_literal: true

require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  def admin
    users(:one)
  end

  def regular
    users(:two)
  end

  test "manage_roles? allows admin" do
    assert UserPolicy.new(admin, regular).manage_roles?
  end

  test "manage_roles? refuses non-admin" do
    assert_not UserPolicy.new(regular, admin).manage_roles?
  end

  test "manage_roles? refuses anonymous" do
    assert_not UserPolicy.new(nil, regular).manage_roles?
  end
end
