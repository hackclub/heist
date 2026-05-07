# frozen_string_literal: true

require "test_helper"

class MailMessagePolicyTest < ActiveSupport::TestCase
  def admin
    users(:one)
  end

  def recipient
    users(:two)
  end

  def stranger
    User.create!(
      slack_id: "stranger_slack",
      hca_id: "stranger_hca",
      display_name: "Stranger",
      email: "stranger@example.com",
      avatar: "x",
      timezone: "UTC",
      roles: [ "user" ]
    )
  end

  test "recipient can read their own message" do
    msg = mail_messages(:unread_for_two)
    assert MailMessagePolicy.new(recipient, msg).show?
    assert MailMessagePolicy.new(recipient, msg).update?
  end

  test "admin can read any message" do
    msg = mail_messages(:unread_for_two)
    assert MailMessagePolicy.new(admin, msg).show?
  end

  test "non-recipient non-admin cannot read" do
    msg = mail_messages(:unread_for_two)
    assert_not MailMessagePolicy.new(stranger, msg).show?
  end

  test "Scope returns only the user's messages for a regular user" do
    ids = MailMessagePolicy::Scope.new(recipient, MailMessage).resolve.ids
    assert_includes ids, mail_messages(:unread_for_two).id
    assert_includes ids, mail_messages(:read_for_two).id
  end

  test "Scope returns all messages for admin" do
    assert_equal MailMessage.count, MailMessagePolicy::Scope.new(admin, MailMessage).resolve.count
  end

  test "Scope returns none for anonymous" do
    assert_equal 0, MailMessagePolicy::Scope.new(nil, MailMessage).resolve.count
  end
end
