module ActsAsEventable
  module Event
    module Base
      def self.included(base)
        base.class_eval do

          # Attribute Modifiers
          # -------------------

          serialize :eventable_attributes

          # Relationships
          # -------------

          belongs_to :eventable, :polymorphic => true
          belongs_to :user, ActsAsEventable::Options.event_belongs_to_user_options.merge(:foreign_key => 'user_id')
          has_many :child_batch_events, :class_name => 'Event', :foreign_key => 'batch_parent_id', :dependent => :destroy

          # Validation
          # ----------

          validates_presence_of :action, :eventable_type # we do not require eventable_id since we won't have it on destroy actions
          validates_length_of :action, :maximum => 255, :allow_blank => true
          validates_presence_of :eventable_id, :if => Proc.new {|e| e.action != 'destroyed'}
          validates_presence_of :eventable_attributes, :if => Proc.new {|e| e.action == 'destroyed'}

          # Callbacks
          # ---------

          before_save :clear_eventable_id, :if => Proc.new {|e| e.action == "destroyed"}

          # Finders
          # -------

          named_scope :batched, :conditions => {:batch_parent_id => nil}
          named_scope :by_batch, lambda {|batch_parent_id| {:conditions => {:batch_parent_id => batch_parent_id}}}
          named_scope :by_user, lambda {|user| {:conditions => {:user_id => user.id}}}
          named_scope :with_users, :include => :user
          named_scope :with_eventables, :include => :eventable

          extend ClassMethods

          # This is redefined so that it returns the eventable
          # object even if it has been destroyed by reconstructing
          # it from the eventable attributes that were saved
          # on the event
          alias_method :eventable_when_not_destroyed, :eventable

          include InstanceMethods
        end
      end

      module ClassMethods
        # This will replace the way rails includes the eventable
        # association with the inject_eventables method below.
        def find(*args)
          options = args.extract_options!

          inject = false

          # see if eventable was meant to be included
          inject ||= remove_eventable_from_includes(options)
          # puts the options back
          args << options

          # now check and see if it was in the scopes
          inject ||= remove_eventable_from_includes(scope(:find))

          result = super(*args)
          inject_eventables(result) if inject
          result
        end

        # Adds the eventable records to events, but attempts to
        # select all events of the same type at once
        def inject_eventables(events, &block)
          if events
            array = events.is_a?(Array)
            events = [events] if !array
            events_by_eventable_type = events.group_by &:eventable_type
            events_by_eventable_type.each do |eventable_type, events|
              events_by_eventable_id = events.group_by &:eventable_id
              ids = events_by_eventable_id.keys.compact
              klass = eventable_type.constantize
              klass = klass.for_events if klass.respond_to? :for_events
              eventables = klass.find(ids)
              eventables.each do |eventable|
                events_by_eventable_id[eventable.id].each { |event| event.set_eventable_target(eventable) }
              end
            end
            array ? events : events.first
          end
        end

        private

        # If options contains includes for eventable, removes it
        # and return true. Otherwise, returns false.
        def remove_eventable_from_includes(options)
          inject = false
          if options
            case includes = options[:include]
              when Array then
                inject = !includes.delete(:eventable).nil?
              when Symbol
                if includes == :eventable
                  options.delete(:include)
                  inject = true
                end
            end
          end
          return inject
        end
      end

      module InstanceMethods
        def eventable
          if eventable_id.nil? && !eventable_attributes.nil?
            eventable_type.constantize.new(eventable_attributes)
          else
            eventable_when_not_destroyed
          end
        end

        private

        # Used to clear the eventable id on destroy events
        def clear_eventable_id
          self.eventable_id = nil
        end
      end

    end # Base
  end # Event
end # ActsAsEventable