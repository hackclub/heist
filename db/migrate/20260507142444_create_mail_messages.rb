class CreateMailMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :mail_messages do |t|
      t.references :user, null: false, foreign_key: true
      t.string :subject, null: false
      t.text :body
      t.string :kind, null: false
      t.datetime :read_at
      t.string :mailable_type
      t.bigint :mailable_id
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :mail_messages, [ :mailable_type, :mailable_id ]
    add_index :mail_messages, :discarded_at
    add_index :mail_messages, [ :user_id, :read_at ], where: "read_at IS NULL", name: "index_mail_messages_unread_per_user"
  end
end
