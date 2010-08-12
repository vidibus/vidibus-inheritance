require "spec_helper"

describe "Cloning" do
  let(:ancestor) { Model.create }
  let(:inheritor) { Model.new }
  let(:anna) { Model.create!(:name => "Anna", :age => 35) }
  let(:leah) { Model.create!(:name => "Leah", :age => 30) }
  
  it "should create a sibling" do
    twin = anna.clone!
    twin.should_not eql(anna)
    twin.name.should eql(anna.name)
    twin.age.should eql(anna.age)
  end
  
  it "should set no ancestor if original did not have one" do
    anna.ancestor_uuid.should be_nil
    anna.ancestor.should be_nil
    twin = anna.clone!
    twin.reload
    twin.ancestor_uuid.should be_nil
    twin.ancestor.should be_nil
  end
  
  context "with ancestor" do
    before { anna.inherit_from!(ancestor) }
    let(:twin) { anna.clone! }
    
    it "should preserve ancestor relation" do
      twin.ancestor.should eql(ancestor)
    end

    it "should not clone inheritors (should it?)" do
      twin.inheritors.should be_empty
    end
    
    it "should set ancestor of orginal" do
      twin.reload.ancestor.should eql(ancestor)
    end

    it "should clone mutated_attributes" do
      twin.reload.mutated_attributes.should eql(anna.mutated_attributes)
    end
  end
  
  context "with embedded documents" do
    before { anna.children.create(:name => "Lisa") }
    
    it "should work for collections" do
      twin = anna.clone!
      twin.children.should have(1).child
    end

    it "should work for single documents" do
      anna.create_location(:name => "Bathroom")
      twin = anna.clone!
      twin.location.name.should eql("Bathroom")
    end
    
    it "should set unique _ids" do
      twin = anna.clone!
      twin.children.first._id.should_not eql(anna.children.first._id)
    end
    
    it "should clone children of embedded documents" do
      lisa = anna.children.first
      lisa.puppets.create(:name => "Gonzo")
      twin = anna.clone!
      lisa_twin = twin.children.first
      lisa_twin.puppets.should have(1).puppet
    end
    
    it "should set unique _id on children of embedded documents" do
      pending("This is really hard to do! Is it inevitable?")
      lisa = anna.children.first
      lisa.puppets.create(:name => "Gonzo")
      twin = anna.clone!
      lisa_twin = twin.children.first
      lisa_twin.puppets.first._id.should_not eql(lisa_twin.puppets.first._id)
    end
    
    context "and ancestor" do
      let(:eva) { Model.create!(:ancestor => anna) }
      let(:twin) { eva.clone!.reload }
      
      it "should maintain correct _reference_id" do
        eva.children.first._reference_id.should eql(anna.children.first._id)
        twin.children.first._reference_id.should eql(anna.children.first._id)
      end
    end
  end
end