class CreateStreamSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :stream_sessions do |t|
      t.datetime :actual_ends_at
      t.datetime :actual_starts_at
      t.datetime :discarded_at
      t.datetime :ends_at, null: false
      t.boolean :is_live, null: false, default: false
      t.datetime :starts_at, null: false
      t.string :title, null: false
      t.string :youtube_url

      t.timestamps
    end

    add_index :stream_sessions, :actual_starts_at
    add_index :stream_sessions, :discarded_at
    add_index :stream_sessions, :is_live
    add_index :stream_sessions, :starts_at
  end
end
