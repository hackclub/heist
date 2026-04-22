# frozen_string_literal: true

require "test_helper"

class RsvpsControllerTest < ActionDispatch::IntegrationTest
  test "records an RSVP and redirects home with ok flag" do
    assert_difference("Rsvp.count", 1) do
      post rsvps_path, params: { email: "heist@example.com" }
    end

    assert_redirected_to root_path(rsvp: "ok")
    assert_equal "heist@example.com", Rsvp.last.email
    assert_equal "landing", Rsvp.last.source
  end

  test "normalizes email to lowercase and trims whitespace" do
    post rsvps_path, params: { email: "  Mixed@Case.COM  " }
    assert_redirected_to root_path(rsvp: "ok")
    assert_equal "mixed@case.com", Rsvp.last.email
  end

  test "duplicate email is a silent no-op" do
    Rsvp.create!(email: "dupe@example.com")

    assert_no_difference("Rsvp.count") do
      post rsvps_path, params: { email: "DUPE@example.com" }
    end

    assert_redirected_to root_path(rsvp: "ok")
  end

  test "invalid email redirects with error" do
    assert_no_difference("Rsvp.count") do
      post rsvps_path, params: { email: "not-an-email" }
    end

    assert_response :redirect
    assert_match(/rsvp=error/, response.location)
  end
end
