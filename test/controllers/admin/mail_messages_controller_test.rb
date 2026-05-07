# frozen_string_literal: true

require "test_helper"

class Admin::MailMessagesControllerTest < ActionDispatch::IntegrationTest
  def admin
    users(:one)
  end

  def regular
    users(:two)
  end

  test "non-admin cannot reach the index" do
    sign_in_as(regular)
    get admin_mail_messages_path
    assert_response :not_found
  end

  test "admin sees the sent mail index" do
    sign_in_as(admin)
    get admin_mail_messages_path
    assert_response :success
    assert_match(/Sent Mail/i, response.body)
  end

  test "admin sees the compose form" do
    sign_in_as(admin)
    get new_admin_mail_message_path
    assert_response :success
    assert_match(/Compose/i, response.body)
  end

  test "create with a single recipient writes one mail" do
    sign_in_as(admin)
    assert_difference("MailMessage.count", 1) do
      post admin_mail_messages_path, params: {
        recipient_id: regular.id,
        subject: "Hi there",
        body: "A direct message."
      }
    end
    assert_redirected_to admin_mail_messages_path
    msg = MailMessage.order(:created_at).last
    assert_equal regular.id, msg.user_id
    assert_equal "admin_message", msg.kind
  end

  test "broadcast creates one mail per kept user" do
    sign_in_as(admin)
    expected = User.kept.count

    assert_difference("MailMessage.count", expected) do
      post admin_mail_messages_path, params: {
        broadcast: "1",
        subject: "Stream starts at 5",
        body: "Be ready."
      }
    end
  end

  test "missing subject is rejected" do
    sign_in_as(admin)
    assert_no_difference("MailMessage.count") do
      post admin_mail_messages_path, params: { recipient_id: regular.id, subject: "", body: "x" }
    end
    assert_redirected_to new_admin_mail_message_path
    assert_match(/subject/i, flash[:alert])
  end

  test "missing recipient and no broadcast is rejected" do
    sign_in_as(admin)
    assert_no_difference("MailMessage.count") do
      post admin_mail_messages_path, params: { subject: "Hi", body: "x" }
    end
    assert_redirected_to new_admin_mail_message_path
    assert_match(/recipient/i, flash[:alert])
  end
end
