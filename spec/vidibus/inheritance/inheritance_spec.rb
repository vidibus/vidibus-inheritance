require "spec_helper"

describe "Inheritance" do
  let(:ancestor) { Model.create }
  let(:inheritor) { Model.new }
  let(:anna) { Model.create!(:name => "Anna", :age => 35) }
  let(:leah) { Model.create!(:name => "Leah", :age => 30) }
  
  it "should happen when creating objects" do
    ancestor # trigger object creation before mocking
    mock.instance_of(Model).inherit_attributes
    Model.create!(:ancestor => ancestor)
  end
  
  it "should happen when ancestor did change" do
    inheritor = Model.create!
    inheritor.ancestor = ancestor
    stub(inheritor).inherit_attributes
    inheritor.save
    inheritor.should have_received.inherit_attributes
  end
  
  it "should not happen when ancestor did not change" do
    inheritor = Model.create!(:ancestor => ancestor)
    dont_allow(inheritor).inherit
    inheritor.save
    # Does not work with RR:
    # inheritor.should_not have_received.inherit
  end
  
  it "should apply ancestor's attributes to inheritor" do
    inheritor.update_attributes(:ancestor => anna)
    inheritor.name.should eql("Anna")
    inheritor.age.should eql(35)
  end
  
  it "should not inherit acquired attributes" do
    inheritor.update_attributes(:ancestor => ancestor)
    Model::ACQUIRED_ATTRIBUTES.should include("uuid")
    inheritor.uuid.should_not eql(ancestor.uuid)
  end
  
  it "should apply ancestor's attributes to inheritor but keep previously mutated attributes" do
    inheritor.update_attributes(:name => "Jenny")
    inheritor.update_attributes(:ancestor => anna)
    inheritor.name.should eql("Jenny")
    inheritor.age.should eql(35)
  end
  
  it "should apply ancestor's attributes to inheritor but keep recently mutated attributes" do
    inheritor.update_attributes(:ancestor => anna, :name => "Jenny")
    inheritor.name.should eql("Jenny")
    inheritor.age.should eql(35)
  end
  
  it "should allow switching the ancestor" do
    inheritor.inherit_from!(anna)
    another_ancestor = Model.create!(:name => "Leah", :age => 30)
    inheritor.inherit_from!(another_ancestor)
    inheritor.ancestor.should eql(another_ancestor)
    inheritor.name.should eql("Leah")
    inheritor.age.should eql(30)
  end
  
  it "should apply changes on ancestor to inheritor" do
    inheritor.inherit_from!(anna)
    inheritor.name.should eql("Anna")
    anna.update_attributes(:name => "Leah")
    inheritor.reload
    inheritor.name.should eql("Leah")
  end
  
  it "should preserve changes on inheritor" do
    inheritor = Model.create(:ancestor => anna)
    inheritor.update_attributes(:name => "Sara")
    inheritor.mutated_attributes.should eql(["name"])
    anna.update_attributes(:name => "Leah")
    inheritor.reload
    inheritor.name.should eql("Sara")
  end
  
  it "should not update inheritor if acquired attributes were changed on ancestor" do
    inheritor.inherit_from!(ancestor)
    Model::ACQUIRED_ATTRIBUTES.should include("updated_at")
    dont_allow(ancestor.inheritors.first).inherit!
    ancestor.update_attributes(:updated_at => Time.now)
  end
  
  it "should not update inheritor if no inheritable attributes were changed on ancestor" do
    inheritor.inherit_from!(anna)
    dont_allow(anna.inheritors.first).inherit!
    anna.update_attributes(:name => "Anna")
  end
  
  it "should be applied before validation" do
    ancestor = Manager.create!(:name => "John")
    invalid = Manager.new
    invalid.should_not be_valid
    valid = Manager.new(:ancestor => ancestor)
    valid.should be_valid
  end
  
  it "should destroy inheritor when destroying ancestor" do
    inheritor.inherit_from!(ancestor)
    ancestor.destroy
    expect { inheritor.reload }.to raise_error(Mongoid::Errors::DocumentNotFound)
  end
  
  context "with embedded collections" do
    before do
      inheritor.inherit_from!(ancestor)
      ancestor.children.create(:name => "Han")
      ancestor.save
      inheritor.reload
    end
    
    it "should inherit subobjects on existing relationship" do
      inheritor.children.should have(1).child
    end
    
    it "should inherit subobjects when relationship gets established" do
      inheritor = Model.new
      inheritor.inherit_from!(ancestor)
      inheritor.children.should have(1).child
      inheritor.reload.children.should have(1).child
    end
    
    it "should add subobjects" do
      ancestor.children << Child.new(:name => "Leah")
      ancestor.save
      ancestor.children.should have(2).children
      inheritor.reload
      inheritor.children.should have(2).children
    end
    
    it "should add subobjects with saving" do
      ancestor.children << Child.new(:name => "Leah")
      ancestor.save
      ancestor.children.should have(2).children
      inheritor.save
      inheritor.reload
      inheritor.children.should have(2).children
    end
    
    it "should not add existing subobjects twice" do
      inheritor.inherit_from!(ancestor)
      inheritor.children.should have(1).child
      inheritor.reload.children.should have(1).child
    end
    
    it "should remove subobjects" do
      inheritor.children.should have(1).child
      ancestor.children.first.destroy
      ancestor.save
      inheritor.reload
      ancestor.children.should have(0).children
      inheritor.children.should have(0).children
    end
    
    it "should remove a single suboject without removing others on inheritor" do
      inheritor.children.create(:name => "Leah")
      inheritor.children.should have(2).children
      ancestor.children.first.destroy
      ancestor.save
      ancestor.children.should have(0).children
      inheritor.reload
      inheritor.children.should have(1).child
    end
    
    it "should update subobjects" do
      ancestor.children.first.name = "Luke"
      ancestor.save
      inheritor.reload
      inheritor.children.first.name.should eql("Luke")
    end
    
    it "should call #update_inherited_attributes for updating subobjects, if available" do
      Child.send(:define_method, :update_inherited_attributes) do
        self.update_attributes(:name => "Callback")
      end
      Child.send(:protected, :update_inherited_attributes)
      ancestor.children.first.name = "Luke"
      ancestor.save
      Child.send(:remove_method, :update_inherited_attributes)
      inheritor.reload
      inheritor.children.first.name.should eql("Callback")
    end
    
    it "should exclude acquired attributes of subobjects" do
      ancestor.children.first.mutated = true
      ancestor.save
      ancestor.children.first.mutated.should be_true
      inheritor.reload
      inheritor.children.first.mutated.should be_false
    end
    
    it "should inherit embedded documents of subobjects" do
      ancestor.children.first.puppets.create(:name => "Goofy")
      ancestor.save
      inheritor.reload
      inheritor.children.first.puppets.should have(1).puppet
    end
    
    context "switching the ancestor" do
      it "should remove previously inherited subobjects" do
        inheritor.inherit_from!(leah)
        inheritor.children.should have(0).children
      end
      
      it "should keep previously inherited subobjects if they have been mutated" do
        inheritor.children.first.update_attributes(:mutated => true)
        inheritor.inherit_from!(leah)
        inheritor.children.should have(1).child
      end
      
      it "should keep own subobjects" do
        inheritor.children.create(:name => "Ronja")
        inheritor.inherit_from!(leah)
        inheritor.children.should have(1).child
      end

      it "should add subobjects of new ancestor" do
        leah.children.create(:name => "Luke")
        inheritor.inherit_from!(leah)
        inheritor.children.should have(1).child
        inheritor.children.first.name.should eql("Luke")
      end
    end
  end
  
  context "with embedded items" do
    before do
      inheritor.inherit_from!(ancestor)
      ancestor.create_location(:name => "Home")
      ancestor.save
      inheritor.reload
    end
    
    it "should inherit subobject on existing relationship" do
      inheritor.location.should_not be_nil
    end
    
    it "should inherit subobjects when relationship gets established" do
      inheritor = Model.new
      inheritor.inherit_from!(ancestor)
      inheritor.location.should_not be_nil
    end
    
    it "should update subobject" do
      ancestor.location.name = "Studio"
      ancestor.save
      inheritor.reload
      ancestor.location.name.should eql("Studio")
      inheritor.location.name.should eql("Studio")
    end
    
    it "should remove subobject" do
      ancestor.location.destroy
      ancestor.save
      inheritor.reload
      ancestor.location.should be_nil
      inheritor.location.should be_nil
    end
    
    it "should exclude acquired attributes of subobject" do
      ancestor.location.mutated = true
      ancestor.save
      ancestor.location.mutated.should be_true
      inheritor.reload
      inheritor.location.mutated.should be_false
    end
    
    it "should inherit embedded documents of subobject" do
      ancestor.location.puppets.create(:name => "Goofy")
      ancestor.save
      inheritor.reload
      inheritor.location.puppets.should have(1).puppet
    end
  end
  
  context "across several generations" do
    let(:grand_ancestor) { Model.create!(:name => "Anna", :age => 97) }
    
    before do
      ancestor.inherit_from!(grand_ancestor)
      inheritor.inherit_from!(ancestor)
    end
    
    it "should apply changes on grand ancestor to inheritor" do
      inheritor.name.should eql("Anna")
      grand_ancestor.update_attributes(:name => "Leah")
      inheritor.reload
      inheritor.name.should eql("Leah")
    end
    
    it "should not apply changes on grand ancestor to inheritor if predecessor has mutations" do
      ancestor.update_attributes(:name => "Jenny")
      grand_ancestor.update_attributes(:name => "Leah")
      inheritor.reload
      inheritor.name.should eql("Jenny")
    end
    
    it "should allow resetting mutated attributes" do
      ancestor.update_attributes(:name => "Sara")
      ancestor.name.should eql("Sara")
      inheritor.reload
      inheritor.name.should eql("Sara")
      ancestor.inherit!(:reset => :name)
      ancestor.name.should eql("Anna")
      inheritor.reload
      inheritor.name.should eql("Anna")
    end
    
    it "should destroy all inheritors when destroying ancestor" do
      grand_ancestor.destroy
      expect { ancestor.reload }.to raise_error(Mongoid::Errors::DocumentNotFound)
      expect { inheritor.reload }.to raise_error(Mongoid::Errors::DocumentNotFound)
    end
    
    context "with embedded collections" do
      before do
        grand_ancestor.children.create(:name => "Han")
        grand_ancestor.save
        ancestor.reload
        inheritor.reload
      end

      it "should inherit subobjects" do
        inheritor.children.should have(1).child
      end

      it "should add subobjects" do
        grand_ancestor.children << Child.new(:name => "Leah")
        grand_ancestor.save
        inheritor.reload
        inheritor.children.should have(2).children
      end

      it "should not add existing subobjects twice" do
        ancestor.inherit_from!(grand_ancestor)
        inheritor.reload
        inheritor.children.should have(1).child
      end

      it "should remove subobjects" do
        inheritor.children.should have(1).child
        grand_ancestor.children.first.destroy
        grand_ancestor.save
        grand_ancestor.children.should have(0).children
        inheritor.reload
        inheritor.children.should have(0).children
      end

      it "should remove a single suboject without removing others on inheritor" do
        inheritor.children.create(:name => "Leah")
        inheritor.children.should have(2).children
        grand_ancestor.children.first.destroy
        grand_ancestor.save
        grand_ancestor.children.should have(0).children
        inheritor.reload
        inheritor.children.should have(1).child
      end

      it "should update subobjects" do
        grand_ancestor.children.first.name = "Luke"
        grand_ancestor.save
        grand_ancestor.children.first.name.should eql("Luke")
        inheritor.reload
        inheritor.children.first.name.should eql("Luke")
      end

      it "should inherit embedded documents of subobjects" do
        grand_ancestor.children.first.puppets.create(:name => "Goofy")
        grand_ancestor.save
        inheritor.reload
        inheritor.children.first.puppets.should have(1).puppet
      end
    end
    
    context "with embedded items" do
      before do
        grand_ancestor.create_location(:name => "Home")
        grand_ancestor.save
        ancestor.reload
        inheritor.reload
      end

      it "should inherit subobject on existing relationship" do
        inheritor.location.should_not be_nil
      end

      it "should inherit subobject when relationship gets established" do
        ancestor = Model.new
        ancestor.inherit_from!(grand_ancestor)
        inheritor = Model.new
        inheritor.inherit_from!(ancestor)
        inheritor.location.should_not be_nil
      end

      it "should update subobject" do
        grand_ancestor.location.name = "Studio"
        grand_ancestor.save
        inheritor.reload
        inheritor.location.name.should eql("Studio")
      end

      it "should remove subobject" do
        grand_ancestor.location.destroy
        grand_ancestor.save
        inheritor.reload
        grand_ancestor.location.should be_nil
        inheritor.location.should be_nil
      end
      
      it "should inherit embedded documents of subobject" do
        grand_ancestor.location.puppets.create(:name => "Goofy")
        grand_ancestor.save
        inheritor.reload
        inheritor.location.puppets.should have(1).puppet
      end
    end
  end

end