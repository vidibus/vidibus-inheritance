require "spec_helper"

describe "Vidibus::Inheritance::Mongoid" do
  class Model
    include Mongoid::Document
    include Vidibus::Uuid::Mongoid
    include Vidibus::Inheritance::Mongoid
    field :name
    field :age, :type => Integer
  end
  
  class Clerk
    include Mongoid::Document
    include Vidibus::Uuid::Mongoid
  end

  describe "validation" do
    before(:each) do
      @inheritor = Model.new
    end
    
    it "should fail if ancestor is of a different object type" do
      invalid_ancestor = Clerk.create
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
      @ancestor = Model.create!
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
      invalid_ancestor = Clerk.create
      @inheritor.ancestor = invalid_ancestor
      @inheritor.ancestor.should eql(invalid_ancestor)
    end
  end
  
  describe "#inherit!" do
    before(:each) do
      @inheritor = Model.new
      @ancestor = Model.create!(:name => "Anna", :age => 35)
    end
    
    it "should call #inherit" do
      stub(@inheritor).inherit
      @inheritor.inherit!
      @inheritor.should have_received(:inherit)
    end
    
    it "should call #save!" do
      stub(@inheritor).save!
      @inheritor.inherit!
      @inheritor.should have_received(:save!)
    end
    
    describe "with mutations" do
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
      @inheritor = Model.new
      @ancestor = Model.new
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
  
  describe "inheritance" do
    before(:each) do
      @inheritor = Model.new
      @ancestor = Model.create!(:name => "Anna", :age => 35)
    end
    
    it "should happen when creating objects" do
      mock.instance_of(Model).inherit
      inheritor = Model.create!(:ancestor => @ancestor)
    end
    
    it "should happen when ancestor did change" do
      inheritor = Model.create!
      inheritor.ancestor = @ancestor
      stub(inheritor).inherit
      inheritor.save
      inheritor.should have_received(:inherit)
    end
    
    it "should not happen when ancestor did not change" do
      inheritor = Model.create!(:ancestor => @ancestor)
      stub(inheritor).inherit
      inheritor.save
      inheritor.should_not have_received(:inherit)
    end
    
    it "should apply ancestor's attributes to inheritor" do
      @inheritor.update_attributes(:ancestor => @ancestor)
      @inheritor.name.should eql("Anna")
      @inheritor.age.should eql(35)
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
  end
end