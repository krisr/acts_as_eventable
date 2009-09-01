module ActsAsEventable
  class Options
    # This can be configured from an initializer as needed
    # for example, to add a clause for acts_as_paranoid
    # so it still selects deleted users or to specify
    # the class_name
    @@event_belongs_to_user_options = {}
    cattr_accessor :event_belongs_to_user_options
  end
end