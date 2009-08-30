require File.dirname(__FILE__) + '/spec_helper'


describe Event do
  include UserSpecHelper
  
  %w(create update publish).each do |action|
    describe 'non destroy event' do
      before(:each) do
        @valid_event_attributes = {
          :action => action,
          :eventable_id => 1,
          :eventable_type => 'Form',
          :eventable_attributes => nil,
          :user_id => 1
        }
      end
    
      it "should create a new instance given valid attributes" do
        Event.create!(@valid_event_attributes)
      end
    
      it "should be invalid without an action" do
        Event.new(@valid_event_attributes.except(:action)).valid?.should == false
      end
    
      it "should be invalid without an eventable_id" do
        Event.new(@valid_event_attributes.except(:eventable_id)).valid?.should == false
      end
    
      it "should be invalid without an eventable_type" do
        Event.new(@valid_event_attributes.except(:eventable_type)).valid?.should == false
      end
    
      it "should be invalid without a user_id" do
        Event.new(@valid_event_attributes.except(:user_id)).valid?.should == false
      end
    end
  end
  
  describe 'destroy event' do
    before(:each) do
      @valid_event_attributes = {
        :action => 'destroyed',
        :eventable_id => nil,
        :eventable_type => 'Form',
        :eventable_attributes => {:title=>'test form'},
        :user_id => 1
      }
    end
    
    it "should create a new instance given valid attributes" do
      Event.create!(@valid_event_attributes)
    end
    
    it "should clear the eventable_id" do
      event = Event.create!(@valid_event_attributes)
      event.eventable_id.should == nil
    end
    
    it "should be valid without an eventable_id" do
      Event.new(@valid_event_attributes.except(:eventable_id)).valid?.should == true
    end
  
    it "should be invalid without an eventable_type" do
      Event.new(@valid_event_attributes.except(:eventable_type)).valid?.should == false
    end
  
    it "should be invalid without a user_id" do
      Event.new(@valid_event_attributes.except(:user_id)).valid?.should == false
    end
    
    it "should be invalid without eventable_attributes" do
      Event.new(@valid_event_attributes.except(:eventable_attributes)).valid?.should == false
    end
  end
  
  describe "with standard user class name" do
    before(:each) do
      @user = create_valid_user
      
      @valid_event_attributes = {
        :action => 'created',
        :eventable_id => 1,
        :eventable_type => 'Form',
        :eventable_attributes => nil,
        :user => @user
      }
    end
    
    it "should create a new instance given valid attributes" do
      Event.create!(@valid_event_attributes)
    end
  end
  
  describe "with non-standard user class name" do
    include AuthorSpecHelper

    before(:each) do
      @author = create_valid_author

      @valid_event_attributes = {
        :action => 'created',
        :eventable_id => 1,
        :eventable_type => 'Form',
        :eventable_attributes => nil,
        :user => @author
      }

      ActiveSupport::Dependencies.remove_constant('Event')
      ActsAsEventable::Options.event_belongs_to_user_options[:class_name] = 'Author'
      load File.join(File.dirname(__FILE__),'../lib/event.rb')
    end

    it "should create a new instance given valid attributes" do
      Event.create!(@valid_event_attributes)
    end
    
    after(:each) do
      ActiveSupport::Dependencies.remove_constant('Event')
      ActsAsEventable::Options.event_belongs_to_user_options.delete(:class_name)
      load File.join(File.dirname(__FILE__),'../lib/event.rb')
    end
  end
end