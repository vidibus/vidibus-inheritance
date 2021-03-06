require "spec_helper"

describe "Vidibus::Inheritance::Mongoid" do
  let(:ancestor) { Model.create }
  let(:inheritor) { Model.new }
  let(:anna) { Model.create!(:name => "Anna", :age => 35) }
  let(:jeanny) { Model.create!(:name => "Jeanny", :age => 17) }
  
  describe "validation" do
    it "should fail if ancestor does not have an UUID" do
      invalid_ancestor = Clerk.create(:name => "John")
      expect {
        inheritor.ancestor = invalid_ancestor
      }.to raise_error
    end
    
    it "should fail if ancestor is of a different object type" do
      invalid_ancestor = Manager.create(:name => "Robin")
      inheritor.ancestor = invalid_ancestor
      inheritor.should be_invalid
      inheritor.errors[:ancestor].should have(1).error
    end
  end
  
  describe "#mutated_attributes" do
    it "should be an empty array by default" do
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
    
    it "should be tracked if data gets modified in a before_validation callback" do
      model = Trude.create
      model.name.should eql("Trude")
      model.mutated_attributes.should eql(["name"])
    end
  end
  
  describe "#mutated?" do
    it "should be false by default" do
      inheritor.mutated?.should be_false
    end
    
    it "should be true if attributes have been changed" do
      inheritor.name = "Anna"
      inheritor.save
      inheritor.reload
      inheritor.mutated?.should be_true
    end
    
    it "should be true if mutated has been set to true" do
      inheritor.mutated = true
      inheritor.save!
      inheritor.reload
      inheritor.mutated?.should be_true
    end
  end
  
  describe "#ancestor=" do
    it "should set an ancestor object" do
      inheritor.ancestor = ancestor
      inheritor.ancestor.should eql(ancestor)
    end
    
    it "should set a persistent ancestor object" do
      inheritor.ancestor = ancestor
      inheritor.save
      inheritor.reload
      inheritor.ancestor.should eql(ancestor)
    end
    
    it "should set the ancestor's uuid" do
      inheritor.ancestor = ancestor
      inheritor.ancestor_uuid.should eql(ancestor.uuid)
    end
    
    it "should not fail if ancestor is of a different object type" do
      invalid_ancestor = Manager.create(:name => "Robin")
      inheritor.ancestor = invalid_ancestor
      inheritor.ancestor.should eql(invalid_ancestor)
    end
  end
  
  describe "#ancestor" do
    it "should return an ancestor object by uuid" do
      inheritor.ancestor_uuid = ancestor.uuid
      inheritor.ancestor.should eql(ancestor)
    end
  end

  describe "#ancestors" do
    it "should return a list of all ancestors" do
      inheritor = Model.create!(:ancestor => ancestor)
      nextgen = Model.create!(:ancestor => inheritor)
      nextgen.ancestors.should eql([inheritor, ancestor])
    end
  end
  
  describe "#root_ancestor" do
    it "should be nil if no ancestor is given" do
      anna.ancestor.should be_nil
      anna.root_ancestor.should be_nil
    end
    
    it "should return ancestor if ancestor is the root one" do
      jeanny.inherit_from!(anna)
      jeanny.root_ancestor.should eql(anna)
    end
    
    it "should be inherited from ancestor" do
      anna.inherit_from!(ancestor)
      jeanny.inherit_from!(anna)
      jeanny.root_ancestor.should eql(ancestor)
    end
    
    it "should be changeable" do
      jeanny.inherit_from!(anna)
      jeanny.root_ancestor.should eql(anna)
      jeanny.inherit_from!(ancestor)
      jeanny.root_ancestor.should eql(ancestor)
    end
  end
  
  describe "#inherit!" do
    it "should call #inherit_attributes once" do
      stub(inheritor)._inherited { true }
      mock(inheritor).inherit_attributes({})
      inheritor.ancestor = anna
      inheritor.inherit!
    end
    
    it "should call #save!" do
      mock(inheritor).save!
      inheritor.ancestor = anna
      inheritor.inherit!
    end
    
    context "with mutations" do
      before { inheritor.update_attributes(:ancestor => anna, :name => "Jenny", :age => 19) }

      it "should keep name and age" do
        inheritor.inherit!
        inheritor.name.should eql("Jenny")
        inheritor.age.should eql(19)
      end
      
      it "should override mutated name attribute with option :reset => :name" do
        inheritor.inherit!(:reset => :name)
        inheritor.name.should eql("Anna")
        inheritor.age.should eql(19)
      end

      it "should override mutated name and age with option :reset => [:name, :age]" do
        inheritor.inherit!(:reset => [:name, :age])
        inheritor.name.should eql("Anna")
        inheritor.age.should eql(35)
      end

      it "should override all mutations with option :reset => true" do
        inheritor.inherit!(:reset => true)
        inheritor.name.should eql("Anna")
        inheritor.age.should eql(35)
      end
    end
  end
  
  describe "#inherit_from!" do
    it "should set ancestor" do
      inheritor.ancestor.should be_nil
      inheritor.inherit_from!(ancestor)
      inheritor.ancestor.should eql(ancestor)
    end
    
    it "should call #inherit!" do
      mock(inheritor).inherit!
      inheritor.inherit!
    end
  
    it "should return the inheritor" do
      Model.new.inherit_from!(ancestor).should be_a(Model)
    end
  end
  
  describe "#inheritors" do
    it "should return all inheritors" do
      inheritor1 = Model.create(:ancestor => ancestor)
      inheritor2 = Model.create(:ancestor => ancestor)
      list = ancestor.inheritors.to_a
      list.should have(2).inheritors
      list.should include(inheritor1)
      list.should include(inheritor2)
    end
  end
  
  describe "#inheritable_documents" do
    it "should perform .inheritable_documents with current object" do
      mock(Model).inheritable_documents(anna, {})
      anna.inheritable_documents
    end
    
    it "should allow options" do
      mock(Model).inheritable_documents(anna, :keys => true)
      anna.inheritable_documents(:keys => true)
    end
  end
  
  describe "#clone!" do
    # see cloning_spec.rb
  end
  
  describe ".inheritable_documents" do
    it "should return embedded relations of a given object" do
      docs = Model.inheritable_documents(anna)
      docs.length.should eql(3)
      docs.should have_key("location")
      docs.should have_key("children")
      docs.should have_key("puppets")
    end
    
    it "should return a collection of documents embedded by embeds_many" do
      anna.children.create(:name => "Lisa")
      docs = Model.inheritable_documents(anna)
      docs["children"].should eql([anna.children.first])
    end
    
    it "should return a document embedded by embeds_one" do
      anna.create_location(:name => "Beach")
      docs = Model.inheritable_documents(anna)
      docs["location"].should eql(anna.location)
    end
    
    it "should return the keys of embedded relations if option :keys is given" do
      keys = Model.inheritable_documents(anna, :keys => true)
      keys.should eql(%w[location puppets children])
    end
  end
  
  describe ".roots" do
    before do
      inheritor.inherit_from!(anna)
      jeanny
    end
    
    it "should return all model that have no ancestor" do
      Model.all.to_a.should have(3).models
      list = Model.roots.to_a
      list.should have(2).models
    end
    
    it "should accept sorting criteria" do
      Model.all.to_a.should have(3).models
      stub_time!(1.hour.since)
      anna.update_attributes(:age => 20)
      list = Model.roots.desc(:updated_at).to_a
      list[0].updated_at.should > list[1].updated_at
    end
    
    it "should accept conditions" do
      list = Model.roots.where(:name => ancestor.name).to_a
      list.should have(1).models
    end
  end
end