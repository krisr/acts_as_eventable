module ActsAsEventable
  module ActionController
    
    def self.included(base) # :nodoc:
      base.extend ClassMethods
    end
    
    module ClassMethods
      def record_events(&event_user)
        write_inheritable_attribute('event_user', &event_user) if block_given?
        
        around_filter :setup_event_user
        
        include InstanceMethods
      end
    end
    
    module InstanceMethods
      private
      
      def setup_event_user
        user = begin
          if block = self.class.read_inheritable_attribute('event_user')
            block.call(self)
          elsif self.respond_to? :current_user
            current_user
          else
            raise "record_events: you must pass a block to fetch the current user or define a 'current_user' method"
          end
        end
        
        Event.record_events(user) {yield}
      end
    end
  end
end