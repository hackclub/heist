class AddReadmeLinkToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :readme_link, :string
  end
end
