# == Schema Information
#
# Table name: stream_appearances
#
#  id                :bigint           not null, primary key
#  role              :integer          default("host"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  stream_session_id :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_stream_appearances_on_stream_session_id              (stream_session_id)
#  index_stream_appearances_on_stream_session_id_and_user_id  (stream_session_id,user_id) UNIQUE
#  index_stream_appearances_on_user_id                        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (stream_session_id => stream_sessions.id)
#  fk_rails_...  (user_id => users.id)
#
class StreamAppearance < ApplicationRecord
  has_paper_trail

  belongs_to :stream_session
  belongs_to :user

  enum :role, { host: 0, cohost: 1, guest: 2 }

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :stream_session_id, message: "is already appearing in this session" }
end
