# ActsAsEventable
module ActsAsEventable
  module ActiveRecord
    
    def self.included(base)
      base.extend ActsMethods
    end
    
    module ActsMethods
      def acts_as_eventable(options={})
        if self.respond_to?(:acts_as_eventable_options)
          raise "acts_as_eventable cannot be used twice on the same model"
        else
          write_inheritable_attribute :acts_as_eventable_options, options
          class_inheritable_reader :acts_as_eventable_options
        
          has_many :events, :as => :eventable, :order => 'id desc'
        
          before_save :event_build
          after_save :event_save
          before_destroy :event_destroy # use before instead of after in case we want to access association before they are destroyed
        
          include BatchingMethods
          include InstanceMethods
          extend ClassMethods
        
          # We need to alias these method chains 
          # to manage batch events
          alias_method_chain :save,            :batch
          alias_method_chain :save!,           :batch
          alias_method_chain :destroy,         :batch
        end
      end
    end
    
    module ClassMethods
      # This is mainly here so we know that we
      # can detect if something is eventable,
      # but also as a convience
      def event_user
        Event.event_user
      end
    end
    
    module BatchingMethods
      def save_with_batch(*args) #:nodoc:
        batch { save_without_batch(*args) }
      end

      def save_with_batch!(*args) #:nodoc:
        batch { save_without_batch!(*args) }
      end
      
      def destroy_with_batch(*args)
        batch { destroy_without_batch(*args) }
      end
      
      private
      
      # This saves the batch events in the correct order with the correct
      # batch id
      def save_batch_events
        batch_parent_id = nil
        batch_size = 0
        batch_event_queue.each do |record|
          event = batch_events[record]
          if event
            event.batch_parent_id = batch_parent_id
            event.save!
            logger.debug "Recorded #{event.eventable_type} #{event.action} event with batch parent id = #{batch_parent_id}"
            batch_parent_id ||= event.id
            batch_size += 1
          end
        end
        
        # set the batch size of the parent
        Event.update_all({:batch_size=>batch_size},{:id=>batch_parent_id}) if batch_parent_id 
      end
      
      def batch(&block)
        status = nil
        if batch_event_state.empty?
          begin
            batch_event_queue << self
            status = block.call
            save_batch_events if status
          ensure
            clear_batch_event_state
          end
        else
          batch_event_queue << self
          status = block.call
        end
        status
      end
      
      def batch_event_queue
        batch_event_state[:queue] ||= []
      end
      
      def batch_events
        batch_event_state[:events] ||= {}
      end
      
      def clear_batch_event_state
        Thread.current['batch_event_state'] = {}
      end
      
      def batch_event_state
        Thread.current['batch_event_state'] ||= {}
      end
    end
    
    module InstanceMethods
      
      # This is to be used for recording arbitrary events as necessary
      # like when a post is published, or a user logs in.
      def record_event!(action, event_user=nil)
        event_user ||= self.class.event_user
        
        raise "Cannot record an event without an event user!" unless event_user
        raise "Cannot record an event on new records" if new_record?
        
        @event = Event.new
        @event.action = action
        @event.user = event_user
        @event.eventable = self
        @event.save!
      end
      
      private
      
      # Destroys all the old events and creates a 
      # new destroy event that also captures the eventable_attributes 
      # so that the record can still be shown in the event log.
      def event_destroy
        self.events.destroy_all

        if event_user = self.class.event_user
          @event = Event.new
          @event.action = 'destroyed'
          @event.eventable = self
          @event.eventable_attributes = self.attributes
          @event.user = event_user
          batch_events[self] = @event
        end
      end
      
      # Builds the initial event and sets the default
      # action type. Does not assign eventable yet because
      # it may not have been saved if this was a new record.
      def event_build
        if event_user = self.class.event_user
          @event = Event.new
          @event.action = case
            when self.new_record? then 'created'
            else 'updated'
          end
          @event.user = event_user
        end
      end
      
      # Saves the event after assigning eventable
      def event_save
        updated_if = acts_as_eventable_options[:updated_if]
        if @event && !(@event.action == 'updated' && updated_if && !updated_if.call(self))
          @event.eventable = self
          batch_events[self] = @event
        end
      end
    end
    
  end
end