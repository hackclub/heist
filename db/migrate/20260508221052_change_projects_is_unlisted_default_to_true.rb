class ChangeProjectsIsUnlistedDefaultToTrue < ActiveRecord::Migration[8.1]
  def change
    change_column_default :projects, :is_unlisted, from: false, to: true
  end
end
