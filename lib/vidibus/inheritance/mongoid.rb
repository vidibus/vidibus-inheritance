module Vidibus
  module Inheritance
    module Mongoid
      extend ActiveSupport::Concern
      
      ACQUIRED_ATTRIBUTES = %w[_id uuid ancestor_uuid mutated_attributes]
      
      included do
        attr_accessor :inherited_attributes
        
        field :ancestor_uuid
        field :mutated_attributes, :type => Array, :default => []
        
        validates :ancestor_uuid, :uuid => { :allow_blank => true }
        validates :ancestor, :ancestor => true, :if => :ancestor_uuid?
        
        before_create :inherit
        before_update :inherit, :if => :ancestor_uuid_changed?
        before_save :track_mutations
      end
      
      # Setter for ancestor.
      def ancestor=(obj)
        self.ancestor_uuid = obj.uuid
        @ancestor = obj
      end
      
      # Returns ancestor object by uuid.
      def ancestor
        @ancestor ||= self.class.where(:uuid => ancestor_uuid).first
      end
      
      # Performs inheritance and saves instance.
      def inherit!(options = {})
        self.inherit(options)
        self.save!
      end
      
      # Performs inheritance from given object.
      def inherit_from!(obj, options = {})
        self.ancestor = obj
        self.inherit!(options)
      end
      
      # Returns true if attributes have been mutated.
      def mutated?
        @is_mutated ||= mutated_attributes.any?
      end
      
      protected
      
      # Performs inheritance while excluding acquired and mutated attributes.
      # Accepts :reset option to overwrite mutated attributes.
      # 
      # Usage:
      #
      #   inherit(:reset => true)          => # Overwrites all mutated attributes
      #   inherit(:reset => :name)         => # Overwrites name only
      #   inherit(:reset => [:name, :age]) => # Overwrites name and age
      #
      def inherit(options = {})
        return unless ancestor
        exceptions = ACQUIRED_ATTRIBUTES
        reset = options[:reset]
        if !reset
          exceptions += mutated_attributes
        elsif reset != true
          reset_attributes = reset.is_a?(Array) ? reset.map { |a| a.to_s } : [reset.to_s]
          exceptions += mutated_attributes - reset_attributes
        end

        self.inherited_attributes = ancestor.attributes.except(*exceptions)
        self.attributes = inherited_attributes
      end
      
      # Stores changed attributes
      def track_mutations
        changed_keys = new_record? ? attributes.keys : changes.keys
        changed_keys -= ACQUIRED_ATTRIBUTES
        if inherited_attributes
          changed_keys -= inherited_attributes.keys
        end
        self.mutated_attributes += changed_keys
        self.mutated_attributes.uniq!
      end
    end
  end
end