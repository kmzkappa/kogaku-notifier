class AddApplicationToUsers < ActiveRecord::Migration
  def change
    add_column :users, :application, :integer, default: 0, null: false
  end
end
