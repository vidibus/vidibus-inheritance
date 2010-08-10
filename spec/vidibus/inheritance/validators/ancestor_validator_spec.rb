require "spec_helper"

describe "Vidibus::Inheritance::Validators::AncestorValidator" do  
  let(:model) { ValidatedModel.new }
  
  it "should be available as ancestor validator" do
    Model.validators_on(:ancestor).first.should be_a_kind_of(Vidibus::Inheritance::Validators::AncestorValidator)
  end
  
  it "should validate an ancestor of same class" do
    model.ancestor = ValidatedModel.new
    model.valid?.should be_true
  end
  
  it "should add an error, if ancestor is of a different class" do
    model.ancestor = Clerk.new
    model.valid?.should be_false
    model.errors[:ancestor].should_not be_blank
  end
end
