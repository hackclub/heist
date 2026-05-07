# frozen_string_literal: true

require "test_helper"

class MailMessagesControllerTest < ActionDispatch::IntegrationTest
  def recipient
    users(:two)
  end

  test "unauthenticated user is redirected from the inbox" do
    get mail_messages_path
    assert_redirected_to root_path
  end

  test "recipient sees their inbox" do
    sign_in_as(recipient)
    get mail_messages_path
    assert_response :success
    assert_match(/Inbox/i, response.body)
    assert_match(/#{Regexp.escape(mail_messages(:unread_for_two).subject)}/i, response.body)
  end

  test "show marks a message as read" do
    sign_in_as(recipient)
    msg = mail_messages(:unread_for_two)

    get mail_message_path(msg)

    assert_response :success
    assert_not_nil msg.reload.read_at
  end

  test "non-recipient cannot show another user's message" do
    sign_in_as(users(:one)) # admin sees all; use an unrelated normal user
    stranger = User.create!(
      slack_id: "show_test_slack",
      hca_id: "show_test_hca",
      display_name: "Show Stranger",
      email: "show_stranger@example.com",
      avatar: "x",
      timezone: "UTC",
      roles: [ "user" ]
    )
    sign_in_as(stranger)
    msg = mail_messages(:unread_for_two)

    get mail_message_path(msg)

    assert_redirected_to root_path
    assert_match(/not authorized/i, flash[:alert])
  end

  test "update redirects back to the inbox after marking read" do
    sign_in_as(recipient)
    msg = mail_messages(:unread_for_two)

    patch mail_message_path(msg)

    assert_redirected_to mail_messages_path
    assert_not_nil msg.reload.read_at
  end

  test "Ship approval delivers a mail to the project owner via the after_update_commit hook" do
    sign_in_as(recipient)
    project = projects(:two)
    project.ships.destroy_all
    ship = project.ships.create!(status: :pending, approved_seconds: 7200)

    assert_difference("MailMessage.count", 1) do
      ship.update!(status: :approved)
    end

    mail = MailMessage.where(mailable: ship).last
    assert_equal recipient.id, mail.user_id
    assert_match(/approved/i, mail.subject)
  end
end
