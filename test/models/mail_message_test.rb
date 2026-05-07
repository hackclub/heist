# frozen_string_literal: true

require "test_helper"

class MailMessageTest < ActiveSupport::TestCase
  test "requires subject and kind" do
    msg = MailMessage.new(user: users(:two))
    assert_not msg.valid?
    assert_includes msg.errors[:subject], "can't be blank"
    assert_includes msg.errors[:kind], "can't be blank"
  end

  test "unread scope returns messages without read_at" do
    assert_includes MailMessage.unread, mail_messages(:unread_for_two)
    assert_not_includes MailMessage.unread, mail_messages(:read_for_two)
  end

  test "mark_read! stamps read_at and is idempotent" do
    msg = mail_messages(:unread_for_two)
    assert_nil msg.read_at

    msg.mark_read!
    first = msg.reload.read_at
    assert_not_nil first

    msg.mark_read!
    assert_equal first, msg.reload.read_at
  end
end
