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

class ModelWithCallback < Model
  before_validation :trudify
  def trudify; self.name = "Trude"; end
end

class Child
  include Mongoid::Document
  field :name
  field :mutated, :type => Boolean
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
  embedded_in :location, :inverse_of => :puppets
  embeds_one :location
end

class Location
  include Mongoid::Document
  field :name
  field :mutated, :type => Boolean
  validates :name, :presence => true
  embedded_in :model, :inverse_of => :location
  embedded_in :child, :inverse_of => :location
  embedded_in :puppet, :inverse_of => :location
  embeds_many :puppets
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

class ValidatedModel
  include ActiveModel::Validations
  attr_accessor :ancestor
  validates :ancestor, :ancestor => true
end

class ValidatedModelSubclass < ValidatedModel
end
