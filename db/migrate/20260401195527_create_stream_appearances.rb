class CreateStreamAppearances < ActiveRecord::Migration[8.1]
  def change
    create_table :stream_appearances do |t|
      t.integer :role, null: false, default: 0
      t.references :stream_session, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :stream_appearances, [ :stream_session_id, :user_id ], unique: true
  end
end
