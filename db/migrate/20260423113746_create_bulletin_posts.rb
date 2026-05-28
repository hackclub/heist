class CreateBulletinPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :bulletin_posts do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.datetime :posted_at, null: false
      t.bigint :author_id
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :bulletin_posts, :posted_at
    add_index :bulletin_posts, :discarded_at
    add_foreign_key :bulletin_posts, :users, column: :author_id, on_delete: :nullify
  end
end
