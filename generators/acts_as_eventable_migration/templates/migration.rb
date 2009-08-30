class ActsAsEventableMigration < ActiveRecord::Migration
  def self.up
    create_table :events do |t|
      t.string :eventable_type, :null => false
      t.integer :eventable_id
      
      t.integer :user_id, :null => false
      
      # this is for when the action is destroy
      t.text :eventable_attributes
      
      # this is for identifying and clustering batch updates
      t.integer :batch_parent_id
      t.integer :batch_size, :null => false, :default => 1
      
      t.string :action, :null => false

      t.datetime :created_at, :null => false
    end
    
    add_index :events, [:eventable_type, :eventable_id]
    add_index :events, [:batch_parent_id, :user_id]
    add_index :events, :batch_parent_id
  end
  
  def self.down
    drop_table :events
  end
end
