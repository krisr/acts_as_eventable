begin
  require File.dirname(__FILE__) + '/../../../../spec/spec_helper'
rescue LoadError
  puts "You need to install rspec in your base app"
  exit
end

# Unload rails app load paths
ActiveSupport::Dependencies.load_paths.reject! { |path| path =~ /\/app(\/|$)/ }
ActiveSupport::Dependencies.load_once_paths.reject! { |path| path =~ /\/app(\/|$)/ }

plugin_spec_dir = File.expand_path(File.dirname(__FILE__))
ActiveRecord::Base.logger = Logger.new(plugin_spec_dir + "/debug.log")

database = YAML::load(IO.read(plugin_spec_dir + "/db/database.yml"))[ENV["DB"] || "sqlite3"]

# clear the database (this will only work with sqllite)
dbfile = File.join(plugin_spec_dir, %w(.. .. .. ..), database[:dbfile])
File.delete(dbfile) if File.exist?(dbfile)

ActiveRecord::Base.establish_connection(database)

load(File.join(plugin_spec_dir, "db", "schema.rb"))

# ensure all the models below aren't already loaded by the app
%w(User Author Form Field Event).each do |klass|
  ActiveSupport::Dependencies.remove_constant(klass) rescue Exception
end

class Event < ActiveRecord::Base
  include ActsAsEventable::Event::Base
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

  @@current_user = nil
  def self.current_user=(user)
    @@current_user = user
  end

  def self.current_user
    @@current_user || nil
  end

  acts_as_eventable do |form, event|
    event.user = form.class.current_user
  end

  has_many :fields, :dependent => :destroy
end

class Field < ActiveRecord::Base
  belongs_to :form

  validates_presence_of :name
  validates_length_of :name, :maximum => 255, :allow_blank => true
  validates_length_of :value, :maximum => 255, :allow_blank => true

  @@current_user = nil
  def self.current_user=(user)
    @@current_user = user
  end

  def self.current_user
    @@current_user
  end

  acts_as_eventable do |field, event|
    event.user = field.class.current_user
  end
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
