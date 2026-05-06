class AddClaimExpiresAtToShips < ActiveRecord::Migration[8.1]
  def change
    add_column :ships, :claim_expires_at, :datetime
    add_index :ships, :claim_expires_at, where: "claim_expires_at IS NOT NULL"
  end
end
