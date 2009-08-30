require File.dirname(__FILE__) + '/spec_helper'



describe ActsAsEventable do
  include UserSpecHelper
  include FormSpecHelper
  
  before(:each) do
    @user = create_valid_user
  end
  
  describe "when event user is not set on create, save, destroy resource" do
    before do
      @form = Form.create!(valid_form_attributes)
      @form.destroy
    end
    
    it "should not create any events" do
      Event.count.should == 0
    end
  end
  
  describe "when explicitly recording an event" do
    before(:each) do
      @form = Form.create!(valid_form_attributes)
    end
    
    describe "when the event user is not set" do
      it "it should raise a Runtime Error" do
        lambda { @form.record_event!('publish') }.should raise_error(RuntimeError, /without an event user/)
      end
    end
    
    describe 'when the resource is new' do
      it "should raise a Runtime Error" do
        lambda { Form.new.record_event!('publish', @user) }.should raise_error(RuntimeError,/new record/)
      end
    end
    
    it 'should create it successfully' do
      @form.record_event!('publish',@user)
    end
  end
  
  describe "when event user is set" do
    before(:each) do
      Event.event_user = @user
      @form = Form.create!(valid_form_attributes)
    end
    
    describe "after create resource" do
      it "should create an event for the resource with action create and no attributes saved" do
        @form.events.length.should == 1
        @form.events.first.action.should == 'created'
        @form.events.first.eventable_attributes.should == nil
        @form.events.first.eventable_id.should == @form.id
        @form.events.first.eventable.should == @form
        @form.events.first.batch_parent_id.should == nil
        @form.events.first.batch_size.should == 1
      end
    end
    
    describe "after update the resource" do
      before(:each) do
        @form.update_attributes(:title=>'Form Title Updated')
      end
      
      it "should create an event for the resource with action update and no attributes saved" do
        @form.events.length.should == 2
        @form.events.first.action.should == 'updated'
        @form.events.first.eventable_attributes.should == nil
        @form.events.first.eventable_id.should == @form.id
        @form.events.first.eventable.should == @form
        @form.events.first.batch_parent_id.should == nil
        @form.events.first.batch_size.should == 1
      end
    end
    
    describe "after update_attribute to update the resource" do
      before(:each) do
        @form.update_attribute(:title,'Form Title Updated')
      end
      
      it "should create an event for the resource with action update and no attributes saved" do
        @form.events.length.should == 2
        @form.events.first.action.should == 'updated'
        @form.events.first.eventable_attributes.should == nil
        @form.events.first.eventable_id.should == @form.id
        @form.events.first.eventable.should == @form
        @form.events.first.batch_parent_id.should == nil
        @form.events.first.batch_size.should == 1
      end
    end
    
    describe "after destroy the resource" do
      before(:each) do
        @form.destroy
      end
      
      it "should remove the existing events and create a new event with action destroy and attributes saved" do
        Event.count.should == 1
        event = Event.find(:first)
        event.action.should == 'destroyed'
        event.eventable_attributes.should_not == nil
        event.eventable_attributes.should == @form.attributes
        
        event.eventable.title == @form.title
        event.eventable.created_at == @form.created_at
        event.eventable.updated_at == @form.updated_at
        event.batch_size.should == 1
      end
    end
    
    describe "after destroy the resource when event user is not set" do
      before(:each) do
        Event.record_events(nil) do
          @form.destroy
        end
      end
      
      it "should remove the all events and not create a new one" do
        Event.count.should == 0
      end
    end
    
    describe "with nested events" do
      before(:each) do
        @base_event_count = Event.count
        @form = Form.new(valid_form_attributes)
        @field = @form.fields.build(valid_field_attributes)
        @form.save!
      end
      
      it "should create two events total" do
        (Event.count - @base_event_count).should == 2
      end
      
      it "should create an event for the form" do
        @form.events.first.should_not == nil
      end
      
      it "should create an event for the field" do
        @field.events.first.should_not == nil
      end
      
      it "should create the form event and then the field event" do
        @field.events.first.id.should > @form.events.first.id
      end
      
      it "should not set batch_parent_id on the Form event" do
        @form.events.first.batch_parent_id.should == nil
      end
      
      it "should set batch_parent_id on the Field event" do
        @field.events.first.batch_parent_id.should == @form.events.first.id
      end
      
      it "should set the batch_size on the Form event to 2" do
        @form.events.first.batch_size.should == 2
      end
      
      it "should set the batch_size on the Field event to 1" do
        @field.events.first.batch_size.should == 1
      end
      
      it "should make the field event a child_batch_event" do
        @form.events.first.child_batch_events.first.should == @field.events.first
      end
      
      describe "after destroying the parent resource" do
        before(:each) do
          @base_destory_event_count = Event.count(:conditions=>{:action=>'destroyed'})
          @form.destroy
        end
        
        it "should create two new destroy events" do
          (Event.count(:conditions=>{:action=>'destroyed'}) - @base_destory_event_count).should == 2
        end
        
        it "should create the form destroy event before the field destroy event" do
          Event.find(:all,:order=>'id desc')[0].eventable_type.should == "Field"
          Event.find(:all,:order=>'id desc')[1].eventable_type.should == "Form"
        end
        
        it "should not set batch_parent_id on the Form event" do
          Event.find(:all,:order=>'id desc')[1].batch_parent_id.should == nil
        end
        
        it "should set batch_parent_id on the Field event to that of the Form event" do
          Event.find(:all,:order=>'id desc')[0].batch_parent_id.should == Event.find(:all,:order=>'id desc')[1].id
        end
        
        it "should set the batch_size on the Form event to 2" do
          Event.find(:all,:order=>'id desc')[1].batch_size.should == 2
        end

        it "should set the batch_size on the Field event to 1" do
          Event.find(:all,:order=>'id desc')[0].batch_size.should == 1
        end

        it "should make the field event a child_batch_event" do
          Event.find(:all,:order=>'id desc')[1].child_batch_events.first.should == Event.find(:all,:order=>'id desc')[0]
        end
      end
    end
    
    after(:each) do
      Event.event_user = nil
    end
  end
end

