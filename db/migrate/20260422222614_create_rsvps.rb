class CreateRsvps < ActiveRecord::Migration[8.1]
  def change
    create_table :rsvps do |t|
      t.string :email, null: false
      t.string :source

      t.timestamps
    end

    add_index :rsvps, "lower(email)", unique: true, name: "index_rsvps_on_lower_email"
  end
end
