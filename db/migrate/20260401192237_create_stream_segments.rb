class CreateStreamSegments < ActiveRecord::Migration[8.1]
  def change
    create_table :stream_segments do |t|
      t.text :description
      t.datetime :discarded_at
      t.datetime :ends_at, null: false
      t.integer :kind, null: false, default: 0
      t.string :label, null: false
      t.datetime :starts_at, null: false
      t.references :stream_session, null: false, foreign_key: true

      t.timestamps
    end

    add_index :stream_segments, :discarded_at
    add_index :stream_segments, [ :stream_session_id, :starts_at ]
  end
end
