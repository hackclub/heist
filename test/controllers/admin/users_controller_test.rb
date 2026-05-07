# frozen_string_literal: true

require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  def admin
    users(:one)
  end

  def regular
    users(:two)
  end

  test "non-admin cannot reach edit" do
    sign_in_as(regular)
    get edit_admin_user_path(regular)
    assert_response :not_found
  end

  test "admin can edit a user" do
    sign_in_as(admin)
    get edit_admin_user_path(regular)
    assert_response :success
    assert_match(/Edit Roles/i, response.body)
  end

  test "admin can update roles" do
    sign_in_as(admin)
    patch admin_user_path(regular), params: { user: { roles: [ "user", "reviewer" ] } }
    assert_redirected_to admin_user_path(regular)
    assert_equal %w[user reviewer], regular.reload.roles
  end

  test "filters out unknown role names silently" do
    sign_in_as(admin)
    patch admin_user_path(regular), params: { user: { roles: [ "admin", "godmode" ] } }
    assert_redirected_to admin_user_path(regular)
    assert_equal [ "admin" ], regular.reload.roles
  end

  test "admin cannot remove their own admin role" do
    sign_in_as(admin)
    patch admin_user_path(admin), params: { user: { roles: [ "user" ] } }
    assert_redirected_to edit_admin_user_path(admin)
    assert_match(/your own admin role/i, flash[:alert])
    assert_includes admin.reload.roles, "admin"
  end

  test "empty roles array is rejected by validation" do
    sign_in_as(admin)
    patch admin_user_path(regular), params: { user: { roles: [] } }
    assert_response :unprocessable_entity
    assert_includes regular.reload.roles, "user"
  end
end
