require File.dirname(__FILE__) + '/spec_helper'

describe ActsAsEventable do
  include UserSpecHelper
  include FormSpecHelper

  before(:each) do
    @user = create_valid_user
  end

  describe "when event user is set" do
    before do
      Form.current_user = @user
    end

    describe "after create" do
      before do
        @event_count = Event.count
        @form = Form.create!(valid_form_attributes)
        @event = Event.last
      end

      it "should create a single event" do
        Event.count.should == @event_count + 1
      end

      it "should set the action to created" do
        @event.action.should == 'created'
      end

      it "should set eventable to the model that triggered the event" do
        @event.eventable.should == @form
      end

      it "should set the parent_id to nil since this wasn't a batch event" do
        @event.batch_parent_id.should == nil
      end

      it "should set the batch_size to 1" do
        @event.batch_size.should == 1
      end
    end

    describe "existing record" do
      before do
        @form = Form.create!(valid_form_attributes)
      end

      it "should update successfully" do
        @form.update_attribute(:title, "Updated Title")
      end

      it "should destroy successfully" do
        @form.destroy
      end

      describe "after update" do
        before do
          @event_count = Event.count
          @form.update_attributes(:title => "updated title")
          @event = Event.last
        end

        it "should create a single event" do
          Event.count.should == @event_count + 1
        end

        it "should set the action to created" do
          @event.action.should == 'updated'
        end

        it "should set eventable to the model that triggered the event" do
          @event.eventable.should == @form
        end

        it "should set the parent_id to nil since this wasn't a batch event" do
          @event.batch_parent_id.should == nil
        end

        it "should set the batch_size to 1" do
          @event.batch_size.should == 1
        end
      end

      describe "after_destroy" do
        before do
          @event_count = Event.count
          @form.destroy
          @event = Event.last
        end

        it "should leave a single event" do
          Event.count.should == 1
        end

        it "should set the action to created" do
          @event.action.should == 'destroyed'
        end

        it "should set eventable to nil since the model no longer exists" do
          @event.eventable.should be_nil
        end

        it "should set the parent_id to nil since this wasn't a batch event" do
          @event.batch_parent_id.should == nil
        end

        it "should set the batch_size to 1" do
          @event.batch_size.should == 1
        end

        it "should record the attributes of the deleted record" do
          @event.eventable_attributes.should_not == nil
          @event.eventable_attributes.should == @form.attributes
        end
      end
    end

    describe "with nested events" do
      before :each do
        Field.current_user = Form.current_user
        @event_count = Event.count
        @form = Form.new(valid_form_attributes)
        @field = @form.fields.build(valid_field_attributes)
        @form.save!
        Field.current_user = nil
      end

      it "should create two events total" do
        (Event.count - @event_count).should == 2
      end

      it "should create an event for each model" do
        @form.events.first.should_not be_nil
        @field.events.first.should_not be_nil
      end

      it "should create the parent event and then the child event" do
        @field.events.first.id.should > @form.events.first.id
      end

      it "should not set batch_parent_id on the parent event" do
        @form.events.first.batch_parent_id.should be_nil
      end

      it "should set the batch_size of the field event to 1 since there were no children events for it" do
        @field.events.first.batch_size.should == 1
      end

      it "should set the batch_size of the form event to 2 since it has a child event" do
        @form.events.first.batch_size.should == 2
      end

      it "should make the first event a child_batch_event of the parent event" do
        @form.events.first.child_batch_events.first.should == @field.events.first
      end


      describe "after destroying the parent resource" do
        before(:each) do
          @base_destory_event_count = Event.count(:conditions=>{:action=>'destroyed'})
          Field.current_user = Form.current_user
          @form.destroy
          Field.current_user = nil
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

      #   describe "with nested events" do
      #     before(:each) do
      #       @base_event_count = Event.count
      #       @form = Form.new(valid_form_attributes)
      #       @field = @form.fields.build(valid_field_attributes)
      #       @form.save!
      #     end
      #
      #     it "should create two events total" do
      #       (Event.count - @base_event_count).should == 2
      #     end
      #
      #     it "should create an event for the form" do
      #       @form.events.first.should_not == nil
      #     end
      #
      #     it "should create an event for the field" do
      #       @field.events.first.should_not == nil
      #     end
      #
      #     it "should create the form event and then the field event" do
      #       @field.events.first.id.should > @form.events.first.id
      #     end
      #
      #     it "should not set batch_parent_id on the Form event" do
      #       @form.events.first.batch_parent_id.should == nil
      #     end
      #
      #     it "should set batch_parent_id on the Field event" do
      #       @field.events.first.batch_parent_id.should == @form.events.first.id
      #     end
      #
      #     it "should set the batch_size on the Form event to 2" do
      #       @form.events.first.batch_size.should == 2
      #     end
      #
      #     it "should set the batch_size on the Field event to 1" do
      #       @field.events.first.batch_size.should == 1
      #     end
      #
      #     it "should make the field event a child_batch_event" do
      #       @form.events.first.child_batch_events.first.should == @field.events.first
      #     end
      #
      #     describe "after destroying the parent resource" do
      #       before(:each) do
      #         @base_destory_event_count = Event.count(:conditions=>{:action=>'destroyed'})
      #         @form.destroy
      #       end
      #
      #       it "should create two new destroy events" do
      #         (Event.count(:conditions=>{:action=>'destroyed'}) - @base_destory_event_count).should == 2
      #       end
      #
      #       it "should create the form destroy event before the field destroy event" do
      #         Event.find(:all,:order=>'id desc')[0].eventable_type.should == "Field"
      #         Event.find(:all,:order=>'id desc')[1].eventable_type.should == "Form"
      #       end
      #
      #       it "should not set batch_parent_id on the Form event" do
      #         Event.find(:all,:order=>'id desc')[1].batch_parent_id.should == nil
      #       end
      #
      #       it "should set batch_parent_id on the Field event to that of the Form event" do
      #         Event.find(:all,:order=>'id desc')[0].batch_parent_id.should == Event.find(:all,:order=>'id desc')[1].id
      #       end
      #
      #       it "should set the batch_size on the Form event to 2" do
      #         Event.find(:all,:order=>'id desc')[1].batch_size.should == 2
      #       end
      #
      #       it "should set the batch_size on the Field event to 1" do
      #         Event.find(:all,:order=>'id desc')[0].batch_size.should == 1
      #       end
      #
      #       it "should make the field event a child_batch_event" do
      #         Event.find(:all,:order=>'id desc')[1].child_batch_events.first.should == Event.find(:all,:order=>'id desc')[0]
      #       end
      #     end
      #   end
      #
      #   after(:each) do
      #     Form.current_user = nil
      #   end


    after do
      Form.current_user = nil
    end
  end

  it "should raise an Exception on create when event user is not set" do
    lambda {
      Form.create!(valid_form_attributes)
    }.should raise_error(/without an event user/)
  end

  describe "existing record" do
    before do
      begin
        Form.current_user = @user
        @form = Form.create!(valid_form_attributes)
      ensure
        Form.current_user = nil
      end
    end

    it "should raise an Exception on update" do
      lambda {
        @form.update_attribute(:title, "Updated Title")
      }.should raise_error(/without an event user/)
    end

    it "should raise an Exception on destroy" do
      lambda {
        @form.destroy
      }.should raise_error(/without an event user/)
    end
  end

  describe ".record_event" do
    before do
      begin
        Form.current_user = @user
        @form = Form.create!(valid_form_attributes)
      ensure
        Form.current_user = nil
      end
    end

    it "should raise an Exception when the event user is not set" do
      lambda {
        @form.record_event!('published')
      }.should raise_error(/without an event user/)
    end

    describe "when event user is set" do
      before do
        Form.current_user = @user
      end

      after do
        Form.current_user = nil
      end

      it "should create the event successfully" do
        @form.record_event!('published')
        last_event = Event.find(:last)
        last_event.eventable.should == @form
        last_event.action.should == 'published'
      end

      describe "when the resource is new" do
        it "should raise a RuntimeError" do
          @form = Form.new(valid_form_attributes)
          lambda {
            @form.record_event!('published')
          }.should raise_error(/new/)
        end
      end
    end
  end



    #
    #   describe "after destroy the resource when event user is not set" do
    #     before(:each) do
    #       @form.destroy
    #     end
    #
    #     it "should remove the all events and not create a new one" do
    #       Event.count.should == 0
    #     end
    #   end
    #
    #   describe "with nested events" do
    #     before(:each) do
    #       @base_event_count = Event.count
    #       @form = Form.new(valid_form_attributes)
    #       @field = @form.fields.build(valid_field_attributes)
    #       @form.save!
    #     end
    #
    #     it "should create two events total" do
    #       (Event.count - @base_event_count).should == 2
    #     end
    #
    #     it "should create an event for the form" do
    #       @form.events.first.should_not == nil
    #     end
    #
    #     it "should create an event for the field" do
    #       @field.events.first.should_not == nil
    #     end
    #
    #     it "should create the form event and then the field event" do
    #       @field.events.first.id.should > @form.events.first.id
    #     end
    #
    #     it "should not set batch_parent_id on the Form event" do
    #       @form.events.first.batch_parent_id.should == nil
    #     end
    #
    #     it "should set batch_parent_id on the Field event" do
    #       @field.events.first.batch_parent_id.should == @form.events.first.id
    #     end
    #
    #     it "should set the batch_size on the Form event to 2" do
    #       @form.events.first.batch_size.should == 2
    #     end
    #
    #     it "should set the batch_size on the Field event to 1" do
    #       @field.events.first.batch_size.should == 1
    #     end
    #
    #     it "should make the field event a child_batch_event" do
    #       @form.events.first.child_batch_events.first.should == @field.events.first
    #     end
    #
    #     describe "after destroying the parent resource" do
    #       before(:each) do
    #         @base_destory_event_count = Event.count(:conditions=>{:action=>'destroyed'})
    #         @form.destroy
    #       end
    #
    #       it "should create two new destroy events" do
    #         (Event.count(:conditions=>{:action=>'destroyed'}) - @base_destory_event_count).should == 2
    #       end
    #
    #       it "should create the form destroy event before the field destroy event" do
    #         Event.find(:all,:order=>'id desc')[0].eventable_type.should == "Field"
    #         Event.find(:all,:order=>'id desc')[1].eventable_type.should == "Form"
    #       end
    #
    #       it "should not set batch_parent_id on the Form event" do
    #         Event.find(:all,:order=>'id desc')[1].batch_parent_id.should == nil
    #       end
    #
    #       it "should set batch_parent_id on the Field event to that of the Form event" do
    #         Event.find(:all,:order=>'id desc')[0].batch_parent_id.should == Event.find(:all,:order=>'id desc')[1].id
    #       end
    #
    #       it "should set the batch_size on the Form event to 2" do
    #         Event.find(:all,:order=>'id desc')[1].batch_size.should == 2
    #       end
    #
    #       it "should set the batch_size on the Field event to 1" do
    #         Event.find(:all,:order=>'id desc')[0].batch_size.should == 1
    #       end
    #
    #       it "should make the field event a child_batch_event" do
    #         Event.find(:all,:order=>'id desc')[1].child_batch_events.first.should == Event.find(:all,:order=>'id desc')[0]
    #       end
    #     end
    #   end
    #
    #   after(:each) do
    #     Form.current_user = nil
    #   end
    # end
end

