class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :mid
      t.string :status
      t.string :application
      t.timestamps
    end
  end
end
