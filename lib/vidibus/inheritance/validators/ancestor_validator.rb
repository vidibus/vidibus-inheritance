module Vidibus
  module Inheritance
    module Validators
      class AncestorValidator < ActiveModel::EachValidator      
        def validate_each(record, attribute, value)
          unless value.class == record.class
            record.errors[attribute] << "must be a #{record.class}"
          end
        end
      end
    end
  end
end