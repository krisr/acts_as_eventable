begin
  require File.dirname(__FILE__) + '/../../../../spec/spec_helper'
rescue LoadError
  puts "You need to install rspec in your base app"
  exit
end

# Unload rails app load paths
Dependencies.load_paths.reject! { |path| path =~ /\/app(\/|$)/ }
Dependencies.load_once_paths.reject! { |path| path =~ /\/app(\/|$)/ }

plugin_spec_dir = File.dirname(__FILE__)
ActiveRecord::Base.logger = Logger.new(plugin_spec_dir + "/debug.log")

database = YAML::load(IO.read(plugin_spec_dir + "/db/database.yml"))[ENV["DB"] || "sqlite3"]

# clear the database (this will only work with sqllite
dbfile = database[:dbfile]
File.delete(dbfile) if File.exist?(dbfile)

ActiveRecord::Base.establish_connection(database)

load(File.join(plugin_spec_dir, "db", "schema.rb"))

# ensure all the models below aren't already loaded by the app
%w(User Author Form Field).each do |klass|
  Dependencies.remove_constant(klass) rescue Exception
end

class User < ActiveRecord::Base
  validates_presence_of :username
  validates_length_of :username, :maximum => 255, :allow_blank => true
end

class Author < ActiveRecord::Base
  validates_presence_of :username
  validates_length_of :username, :maximum => 255, :allow_blank => true
end

class Form < ActiveRecord::Base
  validates_presence_of :title
  validates_length_of :title, :maximum => 255, :allow_blank => true
  
  has_many :fields, :dependent => :destroy
end

class Field < ActiveRecord::Base
  belongs_to :form
  
  validates_presence_of :name
  validates_length_of :name, :maximum => 255, :allow_blank => true
  validates_length_of :value, :maximum => 255, :allow_blank => true
end

module AuthorSpecHelper
  def create_valid_author
    Author.create!({:username=>"Username"})
  end
end

module UserSpecHelper
  def create_valid_user
    User.create!({:username=>"Authorname"})
  end
end

module FormSpecHelper
  def valid_form_attributes
    {:title=>"Form 1"}
  end
  
  def valid_field_attributes
    {:name=>"Field 1", :value=>'Value 1'}
  end
end

module EventSpecHelper
  def valid_event_attributes
  end
end

