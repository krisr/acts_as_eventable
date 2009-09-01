# we do not require event because rails will autoload it
# if we require it here it will not be reloaded in development
# mode and that will cause problems with the User reference
require 'acts_as_eventable/options'
require 'acts_as_eventable/active_record'
require 'acts_as_eventable/event/base'

ActiveRecord::Base.send(:include, ActsAsEventable::ActiveRecord)

ActiveSupport::Dependencies.load_once_paths.delete lib_path