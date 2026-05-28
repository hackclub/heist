# frozen_string_literal: true

require "test_helper"

class MailDeliveryServiceTest < ActiveSupport::TestCase
  def project
    @project ||= projects(:two)
  end

  test "ship_status_changed creates an approval mail with hours rendered" do
    ship = project.ships.create!(status: :pending, approved_seconds: 5400)
    ship.update_columns(status: Ship.statuses[:approved])
    ship.reload

    assert_difference("MailMessage.count", 1) do
      MailDeliveryService.ship_status_changed(ship)
    end

    msg = MailMessage.last
    assert_equal "ship_status_changed", msg.kind
    assert_equal project.user_id, msg.user_id
    assert_equal ship, msg.mailable
    assert_match(/approved/i, msg.subject)
    assert_match(/1\.5 hours/, msg.body)
  end

  test "ship_status_changed creates a returned mail with feedback" do
    ship = project.ships.create!(status: :pending, approved_seconds: 0, feedback: "Add a README")
    ship.update_columns(status: Ship.statuses[:returned])
    ship.reload

    msg = MailDeliveryService.ship_status_changed(ship)

    assert_match(/returned/i, msg.subject)
    assert_match(/Add a README/, msg.body)
  end

  test "ship_status_changed falls back to a placeholder when feedback is blank" do
    ship = project.ships.create!(status: :pending, approved_seconds: 0, feedback: nil)
    ship.update_columns(status: Ship.statuses[:rejected])
    ship.reload

    msg = MailDeliveryService.ship_status_changed(ship)

    assert_match(/not accepted/i, msg.subject)
    assert_match(/no notes/, msg.body)
  end

  test "ship_status_changed returns nil for a pending ship" do
    ship = project.ships.create!(status: :pending, approved_seconds: 0)

    assert_no_difference("MailMessage.count") do
      assert_nil MailDeliveryService.ship_status_changed(ship)
    end
  end
end
