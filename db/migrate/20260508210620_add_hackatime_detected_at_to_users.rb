class AddHackatimeDetectedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :hackatime_detected_at, :datetime
  end
end
