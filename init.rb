# we do not require event because rails will autoload it
# if we require it here it will not be reloaded in development
# mode and that will cause problems with the User reference
require 'acts_as_eventable_options'
require 'acts_as_eventable_action_controller'
require 'acts_as_eventable_active_record'

ActiveRecord::Base.send(:include, ActsAsEventable::ActiveRecord)
ActionController::Base.send(:include, ActsAsEventable::ActionController)

ActiveSupport::Dependencies.load_once_paths.delete lib_path
