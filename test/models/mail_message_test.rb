# frozen_string_literal: true

# == Schema Information
#
# Table name: mail_messages
#
#  id            :bigint           not null, primary key
#  body          :text
#  discarded_at  :datetime
#  kind          :string           not null
#  mailable_type :string
#  read_at       :datetime
#  subject       :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  mailable_id   :bigint
#  user_id       :bigint           not null
#
# Indexes
#
#  index_mail_messages_on_discarded_at                   (discarded_at)
#  index_mail_messages_on_mailable_type_and_mailable_id  (mailable_type,mailable_id)
#  index_mail_messages_on_user_id                        (user_id)
#  index_mail_messages_unread_per_user                   (user_id,read_at) WHERE (read_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
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
