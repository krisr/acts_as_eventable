require File.join(File.dirname(__FILE__),'../../generators/acts_as_eventable_migration/templates/migration')

ActiveRecord::Schema.define(:version => 1) do
  ActsAsEventableMigration.up

  create_table :users do |t|
    t.string :username
    t.timestamps
  end

  create_table :authors do |t|
    t.string :username
    t.timestamps
  end

  create_table :forms do |t|
    t.string :title
    t.timestamps
  end

  create_table :fields do |t|
    t.integer :form_id
    t.string :name
    t.string :value
    t.timestamps
  end
end
