require "spec_helper"

class Model
  include Mongoid::Document
  include Mongoid::Timestamps
  include Vidibus::Uuid::Mongoid
  include Vidibus::Inheritance::Mongoid
  field :name
  field :age, :type => Integer
  embeds_many :children
  embeds_many :puppets
  embeds_one :location
end

class Child
  include Mongoid::Document
  field :name
  validates :name, :presence => true
  embedded_in :model, :inverse_of => :children
  embeds_many :puppets
  embeds_one :location
end

class Puppet
  include Mongoid::Document
  field :name
  validates :name, :presence => true
  embedded_in :child, :inverse_of => :puppets
  embedded_in :model, :inverse_of => :puppets
  embeds_one :location
end

class Location
  include Mongoid::Document
  field :name
  validates :name, :presence => true
  embedded_in :model, :inverse_of => :location
  embedded_in :child, :inverse_of => :location
  embedded_in :puppet, :inverse_of => :location
end

class Manager
  include Mongoid::Document
  include Vidibus::Uuid::Mongoid
  include Vidibus::Inheritance::Mongoid
  field :name
  validates :name, :presence => true
end

class Clerk
  include Mongoid::Document
  field :name
  validates :name, :presence => true
end

describe "Vidibus::Inheritance::Mongoid" do  
  describe "validation" do
    before(:each) do
      @inheritor = Model.new
    end
    
    it "should fail if ancestor does not have an UUID" do
      invalid_ancestor = Clerk.create(:name => "John")
      lambda {
        @inheritor.ancestor = invalid_ancestor
      }.should raise_error
    end
    
    it "should fail if ancestor is of a different object type" do
      invalid_ancestor = Manager.create(:name => "Robin")
      @inheritor.ancestor = invalid_ancestor
      @inheritor.save
      @inheritor.errors[:ancestor].should have(1).error
    end
  end
  
  describe "#mutated_attributes" do
    it "should be an empty array by default" do
      inheritor = Model.new
      inheritor.mutated_attributes.should be_a_kind_of(Array)
      inheritor.mutated_attributes.should be_empty
    end
    
    it "should hold all attributes that have been set on creation" do
      inheritor = Model.create(:name => "Anna")
      inheritor.mutated_attributes.should eql(["name"])
    end
    
    it "should hold all attributes that have been changed after creation" do
      inheritor = Model.create
      inheritor.name = "Anna"
      inheritor.save
      inheritor.mutated_attributes.should eql(["name"])
    end
    
    it "should not contain inherited attributes when ancestor was added on creation" do
      ancestor = Model.create(:name => "Jenny", :age => 23)
      inheritor = Model.create(:ancestor => ancestor)
      inheritor.mutated_attributes.should be_empty
    end
    
    it "should not contain inherited attributes when ancestor was added after creation" do
      inheritor = Model.create
      inheritor.ancestor = Model.create(:name => "Jenny", :age => 23)
      inheritor.save
      inheritor.mutated_attributes.should be_empty
    end
    
    it "should contain unique values" do
      inheritor = Model.create(:name => "Anna")
      inheritor.update_attributes(:name => "Jenny")
      inheritor.mutated_attributes.should eql(["name"])
    end
  end
  
  describe "#mutated?" do
    before(:each) do
      @inheritor = Model.new
    end
    
    it "should be false by default" do
      @inheritor.mutated?.should be_false
    end
    
    it "should be true if attributes have been changed" do
      @inheritor.name = "Anna"
      @inheritor.save
      @inheritor.reload
      @inheritor.mutated?.should be_true
    end
  end
  
  describe "#ancestor" do
    before(:each) do
      @inheritor = Model.new
      @ancestor = Model.create
    end

    it "should return an ancestor object by uuid" do
      @inheritor.ancestor_uuid = @ancestor.uuid
      @inheritor.ancestor.should eql(@ancestor)
    end
  end
  
  describe "#ancestor=" do
    before(:each) do
      @inheritor = Model.new
      @ancestor = Model.create
    end

    it "should set an ancestor object" do
      @inheritor.ancestor = @ancestor
      @inheritor.ancestor.should eql(@ancestor)
    end
    
    it "should set a persistent ancestor object" do
      @inheritor.ancestor = @ancestor
      @inheritor.save
      @inheritor.reload
      @inheritor.ancestor.should eql(@ancestor)
    end
    
    it "should set the ancestor's uuid" do
      @inheritor.ancestor = @ancestor
      @inheritor.ancestor_uuid.should eql(@ancestor.uuid)
    end
    
    it "should not fail if ancestor is of a different object type" do
      invalid_ancestor = Manager.create(:name => "Robin")
      @inheritor.ancestor = invalid_ancestor
      @inheritor.ancestor.should eql(invalid_ancestor)
    end
  end
  
  describe "#inherit!" do
    before(:each) do
      @ancestor = Model.create!(:name => "Anna", :age => 35)
      @inheritor = Model.new
    end
    
    it "should call #inherit_attributes once" do
      stub(@inheritor)._inherited { true }
      stub(@inheritor).inherit_attributes
      @inheritor.ancestor = @ancestor
      @inheritor.inherit!
      @inheritor.should have_received.inherit_attributes.once.with_any_args
    end
    
    it "should call #save!" do
      stub(@inheritor).save!
      @inheritor.ancestor = @ancestor
      @inheritor.inherit!
      @inheritor.should have_received.save!
    end
    
    context "with mutations" do
      before(:each) do
        @inheritor.update_attributes(:ancestor => @ancestor, :name => "Jenny", :age => 19)
      end
      
      it "should keep name and age" do
        @inheritor.inherit!
        @inheritor.name.should eql("Jenny")
        @inheritor.age.should eql(19)
      end
      
      it "should override mutated name attribute with option :reset => :name" do
        @inheritor.inherit!(:reset => :name)
        @inheritor.name.should eql("Anna")
        @inheritor.age.should eql(19)
      end

      it "should override mutated name and age with option :reset => [:name, :age]" do
        @inheritor.inherit!(:reset => [:name, :age])
        @inheritor.name.should eql("Anna")
        @inheritor.age.should eql(35)
      end

      it "should override all mutations with option :reset => true" do
        @inheritor.inherit!(:reset => true)
        @inheritor.name.should eql("Anna")
        @inheritor.age.should eql(35)
      end
    end
  end
  
  describe "#inherit_from!" do
    before(:each) do
      @ancestor = Model.create(:name => "Anna")
      @inheritor = Model.new
    end
    
    it "should set ancestor" do
      @inheritor.ancestor.should be_nil
      @inheritor.inherit_from!(@ancestor)
      @inheritor.ancestor.should eql(@ancestor)
    end
    
    it "should call #inherit!" do
      stub(@inheritor).inherit!
      @inheritor.inherit!
      @inheritor.should have_received(:inherit!)
    end
  end
  
  describe "#inheritors" do
    before(:each) do
      @ancestor = Model.create!(:name => "Anna", :age => 35)
    end
    
    it "should return all inheritors" do
      inheritor1 = Model.create(:ancestor => @ancestor)
      inheritor2 = Model.create(:ancestor => @ancestor)
      @ancestor.inheritors.should have(2).inheritors
      @ancestor.inheritors.should include(inheritor1)
      @ancestor.inheritors.should include(inheritor2)
    end
  end
  
  describe "inheritance" do
    before(:each) do
      @inheritor = Model.new
      @ancestor = Model.create!(:name => "Anna", :age => 35)
    end
    
    it "should happen when creating objects" do
      mock.instance_of(Model).inherit_attributes
      inheritor = Model.create!(:ancestor => @ancestor)
    end
    
    it "should happen when ancestor did change" do
      inheritor = Model.create!
      inheritor.ancestor = @ancestor
      stub(inheritor).inherit_attributes
      inheritor.save
      inheritor.should have_received.inherit_attributes
    end
    
    it "should not happen when ancestor did not change" do
      inheritor = Model.create!(:ancestor => @ancestor)
      dont_allow(inheritor).inherit
      inheritor.save
      # Does not work with RR:
      # inheritor.should_not have_received.inherit
    end
    
    it "should apply ancestor's attributes to inheritor" do
      @inheritor.update_attributes(:ancestor => @ancestor)
      @inheritor.name.should eql("Anna")
      @inheritor.age.should eql(35)
    end
    
    it "should not inherit acquired attributes" do
      @inheritor.update_attributes(:ancestor => @ancestor)
      Model::ACQUIRED_ATTRIBUTES.should include("uuid")
      @inheritor.uuid.should_not eql(@ancestor.uuid)
    end
    
    it "should apply ancestor's attributes to inheritor but keep previously mutated attributes" do
      @inheritor.update_attributes(:name => "Jenny")
      @inheritor.update_attributes(:ancestor => @ancestor)
      @inheritor.name.should eql("Jenny")
      @inheritor.age.should eql(35)
    end
    
    it "should apply ancestor's attributes to inheritor but keep recently mutated attributes" do
      @inheritor.update_attributes(:ancestor => @ancestor, :name => "Jenny")
      @inheritor.name.should eql("Jenny")
      @inheritor.age.should eql(35)
    end
    
    it "should allow switching the ancestor" do
      @inheritor.inherit_from!(@ancestor)
      another_ancestor = Model.create!(:name => "Leah", :age => 30)
      @inheritor.inherit_from!(another_ancestor)
      @inheritor.ancestor.should eql(another_ancestor)
      @inheritor.name.should eql("Leah")
      @inheritor.age.should eql(30)
    end
    
    it "should apply changes on ancestor to inheritor" do
      @inheritor.inherit_from!(@ancestor)
      @inheritor.name.should eql("Anna")
      @ancestor.update_attributes(:name => "Leah")
      @inheritor.reload
      @inheritor.name.should eql("Leah")
    end
    
    it "should not update inheritor if acquired attributes were changed on ancestor" do
      @inheritor.inherit_from!(@ancestor)
      Model::ACQUIRED_ATTRIBUTES.should include("updated_at")
      dont_allow(@ancestor.inheritors.first).inherit!
      @ancestor.update_attributes(:updated_at => Time.now)
    end
    
    it "should not update inheritor if no inheritable attributes were changed on ancestor" do
      @inheritor.inherit_from!(@ancestor)
      dont_allow(@ancestor.inheritors.first).inherit!
      @ancestor.update_attributes(:name => "Anna")
    end
    
    it "should be applied before validation" do
      ancestor = Manager.create!(:name => "John")
      invalid = Manager.new
      invalid.should_not be_valid
      valid = Manager.new(:ancestor => ancestor)
      valid.should be_valid
    end
    
    context "with embedded collections" do
      before(:each) do
        @inheritor.inherit_from!(@ancestor)
        @ancestor.children.create(:name => "Han")
        @ancestor.save
        @inheritor.reload
      end
      
      it "should inherit subobjects on existing relationship" do
        @inheritor.children.should have(1).child
      end
      
      it "should inherit subobjects when relationship gets established" do
        inheritor = Model.new
        inheritor.inherit_from!(@ancestor)
        inheritor.children.should have(1).child
        inheritor.reload.children.should have(1).child
      end
      
      it "should add subobjects" do
        @ancestor.children << Child.new(:name => "Leah")
        @ancestor.save
        @ancestor.children.should have(2).children
        @inheritor.reload
        @inheritor.children.should have(2).children
      end
      
      it "should add subobjects with saving" do
        @ancestor.children << Child.new(:name => "Leah")
        @ancestor.save
        @ancestor.children.should have(2).children
        @inheritor.save
        @inheritor.reload
        @inheritor.children.should have(2).children
      end
      
      it "should not add existing subobjects twice" do
        @inheritor.inherit_from!(@ancestor)
        @inheritor.children.should have(1).child
        @inheritor.reload.children.should have(1).child
      end
      
      it "should remove subobjects" do
        @inheritor.children.should have(1).child
        @ancestor.children.first.destroy
        @ancestor.save
        @inheritor.reload
        @ancestor.children.should have(0).children
        @inheritor.children.should have(0).children
      end
      
      it "should apply changed subobjects" do
        @ancestor.children.first.name = "Luke"
        @ancestor.save
        @inheritor.reload
        @ancestor.children.first.name.should eql("Luke")
        @inheritor.children.first.name.should eql("Luke")
      end
    end
    
    context "with embedded items" do
      before(:each) do
        @inheritor.inherit_from!(@ancestor)
        @ancestor.create_location(:name => "Home")
        @ancestor.save
        @inheritor.reload
      end
      
      it "should inherit subobject on existing relationship" do
        @inheritor.location.should_not be_nil
      end
      
      it "should inherit subobjects when relationship gets established" do
        inheritor = Model.new
        inheritor.inherit_from!(@ancestor)
        inheritor.location.should_not be_nil
      end
      
      it "should apply changes of subobject" do
        @ancestor.location.name = "Studio"
        @ancestor.save
        @inheritor.reload
        @ancestor.location.name.should eql("Studio")
        @inheritor.location.name.should eql("Studio")
      end
      
      it "should remove subobject" do
        @ancestor.location.destroy
        @ancestor.save
        @inheritor.reload
        @ancestor.location.should be_nil
        @inheritor.location.should be_nil
      end
    end
    
    context "across several generations" do
      before(:each) do
        @grand_ancestor = Model.create!(:name => "Anna", :age => 97)
        @ancestor = Model.new
        @ancestor.inherit_from!(@grand_ancestor)
        @inheritor.inherit_from!(@ancestor)
      end
      
      it "should apply changes on grand ancestor to inheritor" do
        @inheritor.name.should eql("Anna")
        @grand_ancestor.update_attributes(:name => "Leah")
        @inheritor.reload
        @inheritor.name.should eql("Leah")
      end
      
      it "should not apply changes on grand ancestor to inheritor if predecessor has mutations" do
        @ancestor.update_attributes(:name => "Jenny")
        @grand_ancestor.update_attributes(:name => "Leah")
        @inheritor.reload
        @inheritor.name.should eql("Jenny")
      end
      
      context "with embedded collections" do
        before(:each) do
          @grand_ancestor.children.create(:name => "Han")
          @grand_ancestor.save
          @ancestor.reload
          @inheritor.reload
        end

        it "should inherit subobjects" do
          @inheritor.children.should have(1).child
        end

        it "should add subobjects" do
          @grand_ancestor.children << Child.new(:name => "Leah")
          @grand_ancestor.save
          @inheritor.reload
          @inheritor.children.should have(2).children
        end

        it "should not add existing subobjects twice" do
          @ancestor.inherit_from!(@grand_ancestor)
          @inheritor.reload
          @inheritor.children.should have(1).child
        end

        it "should remove subobjects" do
          @inheritor.children.should have(1).child
          @grand_ancestor.children.first.destroy
          @grand_ancestor.save
          @grand_ancestor.children.should have(0).children
          @inheritor.reload
          @inheritor.children.should have(0).children
        end

        it "should apply changed subobjects" do
          @grand_ancestor.children.first.name = "Luke"
          @grand_ancestor.save
          @grand_ancestor.children.first.name.should eql("Luke")
          @inheritor.reload
          @inheritor.children.first.name.should eql("Luke")
        end
      end
      
      context "with embedded items" do
        before(:each) do
          @grand_ancestor.create_location(:name => "Home")
          @grand_ancestor.save
          @ancestor.reload
          @inheritor.reload
        end

        it "should inherit subobject on existing relationship" do
          @inheritor.location.should_not be_nil
        end

        it "should inherit subobjects when relationship gets established" do
          ancestor = Model.new
          ancestor.inherit_from!(@grand_ancestor)
          inheritor = Model.new
          inheritor.inherit_from!(ancestor)
          inheritor.location.should_not be_nil
        end

        it "should apply changes of subobject" do
          @grand_ancestor.location.name = "Studio"
          @grand_ancestor.save
          @inheritor.reload
          @inheritor.location.name.should eql("Studio")
        end

        it "should remove subobject" do
          @grand_ancestor.location.destroy
          @grand_ancestor.save
          @inheritor.reload
          @grand_ancestor.location.should be_nil
          @inheritor.location.should be_nil
        end
      end
    end
    
    
    # context "with embedded documents that do not support inheritance" do
    #   before(:each) do
    #     @ancestor.puppets.create!(:name => "Gigi")
    #   end
    #   
    #   it "should inherit subobjects" do
    #     @inheritor.inherit_from!(@ancestor)
    #     @inheritor.puppets.should have(1).child
    #     @inheritor.reload.puppets.should have(1).child
    #   end
    #   
    #   it "should inherit subobjects that do not support inheritance" do
    #     @inheritor.inherit_from!(@ancestor)
    #     @inheritor.puppets.should have(1).child
    #     @inheritor.reload.puppets.should have(1).child
    #   end
    #   
    #   it "should reset acquired attributes on subobjects" do
    #     stub_time!('01.01.2010 14:00')
    #     @inheritor.inherit_from!(@ancestor)
    #     @inheritor.puppets.first.created_at.should eql(Time.parse('01.01.2010 14:00'))
    #   end
    #   
    #   it "should reset acquired attributes on subobjects recursively" do
    #     @ancestor.puppets.first.location = Location.new(:color => "red")
    #   end
    #   
    #   it "should allow UUID on subobjects" do
    #     @inheritor.inherit_from!(@ancestor)
    #     @inheritor.puppets.first.uuid.should_not be_nil
    #     @inheritor.puppets.first.uuid.should_not eql(@ancestor.puppets.first.uuid)
    #   end
    # end
  end
  
  # describe "embedded documents" do
  #   context "on a new object" do
  #     before(:each) do
  #       @model = Model.new(:name => "Anna", :age => 35)
  #     end
  #     
  #     it "should call #notify_parent after create" do
  #       stub.instance_of(Child).notify_parent
  #       @model.children.create(:name => "Han")
  #       @model.children.first.should have_received.notify_parent.twice # Mongoid seems to execute #create twice...
  #     end
  #     
  #     # it "should update parent after create without errors" do
  #     #   stub(@model).save
  #     #   @model.children.create(:name => "Han")
  #     #   @model.should have_received.save.once
  #     # end
  #     # 
  #     # it "should not update parent if create fails" do
  #     #   dont_allow(@model).save
  #     #   @model.children.create
  #     # end
  #   end
  #   
  #   context "on an existing object" do
  #     before(:each) do
  #       @model = Model.create!(:name => "Anna", :age => 35)
  #     end
  #     
  #     it "should call #notify_parent after create" do
  #       stub.instance_of(Child).notify_parent
  #       @model.children.create(:name => "Han")
  #       @model.children.first.should have_received.notify_parent
  #     end
  #     
  #     it "should not call #notify_parent after create" do
  #       stub.instance_of(Child).notify_parent
  #       @model.children.create(:name => "Han")
  #       @model.children.first.should have_received.notify_parent
  #     end
  #     
  #     it "should not call #notify_parent after save" do
  #       child = @model.children.create(:name => "Han")
  #       dont_allow(child).notify_parent
  #       child.update_attributes!(:name => "Solo")
  #     end
  # 
  #     it "should update parent after create without errors" do
  #       stub(@model).save
  #       @model.children.create(:name => "Han")
  #       @model.should have_received.save
  #     end
  #     
  #     it "should not update parent if create fails" do
  #       dont_allow(@model).save
  #       @model.children.create
  #     end
  #   end
  #   
  #   # it "should update parent when adding subobjects" do
  #   #   stub(@ancestor).save_parent
  #   #   @ancestor.children.create!(:name => "Han")
  #   #   @ancestor.should have_received.save_parent
  #   # end
  #   
  #   it "should update parent when they get destroyed" do
  #     
  #     # it "should call #remove after destroy" do
  #     #   child = @model.children.create!(:name => "Han")
  #     #   stub(child).notify_parent
  #     #   child.destroy
  #     #   child.should have_received.notify_parent
  #     # end
  #     pending
  #   end
  # end
end