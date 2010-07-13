require "spec_helper"

describe "Vidibus::Inheritance::Validators::AncestorValidator" do
  class ValidModel
    include ActiveModel::Validations
    attr_accessor :ancestor
    validates :ancestor, :ancestor => true
  end
  
  class InvalidModel; end
  
  before(:each) do
    @model = ValidModel.new
  end
  
  it "should be available as ancestor validator" do
    Model.validators_on(:ancestor).first.should be_a_kind_of(Vidibus::Inheritance::Validators::AncestorValidator)
  end
  
  it "should validate an ancestor of same class" do
    @model.ancestor = ValidModel.new
    @model.valid?.should be_true
  end
  
  it "should add an error, if ancestor is of a different class" do
    @model.ancestor = InvalidModel.new
    @model.valid?.should be_false
    @model.errors[:ancestor].should_not be_blank
  end
end
