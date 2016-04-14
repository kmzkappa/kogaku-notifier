class FixUsersCols < ActiveRecord::Migration
  def change
    add_column    :users, :enabled,     :boolean
    change_column :users, :mid,         :string,  null: false
    remove_column :users, :application
    remove_column :users, :status
  end
end
