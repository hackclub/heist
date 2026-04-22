# frozen_string_literal: true

require "test_helper"

class RsvpPolicyTest < ActiveSupport::TestCase
  test "anonymous visitor can create an RSVP" do
    assert RsvpPolicy.new(nil, Rsvp).create?
  end

  test "signed-in user can also create an RSVP" do
    assert RsvpPolicy.new(users(:one), Rsvp).create?
  end
end
