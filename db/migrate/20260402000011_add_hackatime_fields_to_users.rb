class AddHackatimeFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :hackatime_token, :text
    add_column :users, :hackatime_uid, :string
  end
end
