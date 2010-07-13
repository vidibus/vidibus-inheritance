require "inheritance/validators/ancestor_validator"

# Add AncestorValidator
ActiveModel::Validations.send(:include, Vidibus::Inheritance::Validators)