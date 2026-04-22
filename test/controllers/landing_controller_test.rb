# frozen_string_literal: true

require "test_helper"

class LandingControllerTest < ActionDispatch::IntegrationTest
  test "renders landing page for unauthenticated visitors" do
    get root_path

    assert_response :success
    assert_select "h1.heist-title"
    assert_select "a.heist-btn--login", text: /LOG IN/
    assert_select "input[type=email][name='email']"
    assert_select ".heist-crt--counter"
    assert_select ".heist-crt--stream"
  end

  test "counts only kept users with hackatime connected" do
    Rails.cache.clear
    active = User.kept.where.not(hackatime_uid: nil).count
    User.create!(
      email: "active@example.com",
      display_name: "Active",
      avatar: "a.png",
      timezone: "UTC",
      slack_id: "S_active",
      hca_id: "hca_active_#{SecureRandom.hex(4)}",
      roles: [ "user" ],
      hackatime_uid: "ha_#{SecureRandom.hex(4)}"
    )

    get root_path
    assert_response :success
    assert_includes response.body, "#{active + 1}"
  end
end
