module Vidibus
  module Inheritance
    module Mongoid
      extend ActiveSupport::Concern

      ACQUIRED_ATTRIBUTES = %w[_id uuid ancestor_uuid mutated_attributes mutated created_at updated_at version versions]
      
      included do
        attr_accessor :inherited_attributes, :_inherited
        attr_protected :mutated_attributes, :mutated
        
        field :ancestor_uuid
        field :mutated_attributes, :type => Array, :default => []
        field :mutated, :type => Boolean

        validates :ancestor_uuid, :uuid => { :allow_blank => true }
        validates :ancestor, :ancestor => true, :if => :ancestor_uuid?

        before_validation :preprocess 
        after_save :postprocess
      
        # Callback of Mongoid when deleting a collection item on a parent object.
        def remove(*args)
          super(*args)
        end

        # Setter for ancestor.
        def ancestor=(obj)
          self.ancestor_uuid = obj.uuid
          @ancestor = obj
        end
      
        # Returns ancestor object by uuid.
        def ancestor
          @ancestor ||= begin
            self.class.where(:uuid => ancestor_uuid).first if ancestor_uuid
          end
        end
      
        # Performs inheritance and saves instance with force.
        # Accepts :reset option to overwrite mutated attributes.
        # 
        # Usage:
        #
        #   inherit!(:reset => true)          => # Overwrites all mutated attributes
        #   inherit!(:reset => :name)         => # Overwrites name only
        #   inherit!(:reset => [:name, :age]) => # Overwrites name and age
        #
        def inherit!(options = {})
          self.inherit_attributes(options)
          self.save!
        end
      
        # Performs inheritance from given object.
        # Accepts :reset option to overwrite mutated attributes.
        def inherit_from!(obj, options = {})
          self.ancestor = obj
          self.inherit!(options)
        end
      
        # Returns list of objects that inherit from this ancestor.
        def inheritors
          self.class.where(:ancestor_uuid => uuid).to_a
        end
      
        # Returns embedded documents.
        def inheritable_documents
          self.class.inheritable_documents(self)
        end
        
        # Returns true if attributes have been mutated.
        def mutated?
          @is_mutated ||= mutated || mutated_attributes.any?
        end

        protected
      
        # Performs inheritance of attributes while excluding acquired and mutated ones.
        # Accepts :reset option to overwrite mutated attributes.
        def inherit_attributes(options = {})
          self._inherited = true
          exceptions = ACQUIRED_ATTRIBUTES
          reset = options[:reset]
          if !reset
            exceptions += mutated_attributes
          elsif reset != true
            reset_attributes = reset.is_a?(Array) ? reset.map { |a| a.to_s } : [reset.to_s]
            exceptions += mutated_attributes - reset_attributes
          end
          exceptions += ancestor.inheritable_documents.keys
          self.attributes = self.inherited_attributes = ancestor.attributes.except(*exceptions)
        end
        
        # Performs inheritance of documents.
        def inherit_documents
          return unless ancestor
          return unless list = ancestor.inheritable_documents
          for association, inheritable in list
          
            # embeds_many
            if inheritable.is_a?(Array)
              collection = new_record? ? self.send(association) : self.reload.send(association)
              existing_ids = collection.map do |a| 
                begin
                  a._reference_id
                rescue
                end
              end
              
              for obj in inheritable
                attrs = inheritable_document_attributes(obj)
                if existing_ids.include?(obj._id)
                  doc = collection.where(:_reference_id => obj._id).first
                  update_inheritable_document(doc, attrs)
                else
                  doc = collection.create!(attrs)
                end
              end
              
              obsolete = existing_ids - inheritable.map { |i| i._id }
              if obsolete.any?
                collection.destroy_all(:_reference_id => obsolete)
              end
            
            # embeds_one
            else
              if inheritable
                attrs = inheritable_document_attributes(inheritable)
                if doc = self.send("#{association}")
                  update_inheritable_document(doc, attrs)
                else
                  self.send("create_#{association}", attrs)
                end
              elsif existing = self.send("#{association}")
                existing.destroy
              end
            end
          end
        end

        # Performs actions before saving.
        def preprocess
          track_mutations
          inherit_attributes if inherit?
        end
      
        # Performs actions after saving.
        def postprocess
          inherit_documents if embed?
          update_inheritors
        end

        # Returns true if inheritance should be applied on inheritor.
        def inherit?
          !_inherited and ancestor and (new_record? or ancestor_uuid_changed?)
        end
      
        # Returns true if this documents has any inheritable documents.
        def embed?
          inheritable_documents.any?
        end

        # Stores changed attributes as #mutated_attributes unless they have been inherited recently.
        def track_mutations
          changed_items = new_record? ? attributes.keys : changes.keys
          changed_items -= ACQUIRED_ATTRIBUTES
          if inherited_attributes
            for key, value in inherited_attributes
              changed_items.delete(key) if value == attributes[key]
            end
            self.inherited_attributes = nil
          end
          self.mutated_attributes += changed_items
          self.mutated_attributes.uniq!
        end
        
        # Updates an given document with given attributes.
        def update_inheritable_document(doc, attrs)
          update_inheritable_document_attributes(doc, attrs)
          update_inheritable_document_children(doc, attrs)
        end
        
        # Updates an given document with given attributes.
        # This will perform #update_inherited_attributes on document, if this callback method is available.
        def update_inheritable_document_attributes(doc, attrs)
          if doc.respond_to?(:update_inherited_attributes)
            doc.send(:update_inherited_attributes, attrs)
          else
            doc.update_attributes(attrs)
          end
        end
        
        # Updates children of given embedded document.
        # Because update_attributes won't modify the hash of children, a custom database update is needed.
        def update_inheritable_document_children(doc, attrs)
          inheritable_documents = self.class.inheritable_documents(doc, :keys => true)
          idocs = attrs.only(*inheritable_documents)
          query = {}
          for k,v in idocs
            query["#{doc._position}.#{k}"] = v
          end
          _collection.update(_selector, { "$set" => query })
        end
        
        # Returns list of inheritable attributes of a given document.
        # The list will include the _id as reference.
        def inheritable_document_attributes(doc)
          attrs = doc.attributes.except(*ACQUIRED_ATTRIBUTES)
          attrs[:_reference_id] = doc._id
          attrs
        end
      
        # Applies changes to inheritors.
        def update_inheritors
          return unless inheritors.any?
          inheritors.each(&:inherit!)
        end
        
        class << self
      
          # Returns embedded documents of given document.
          def inheritable_documents(doc, options = {})
            keys = options[:keys]
            collection = keys ? [] : {}
            for name, association in doc.associations
              next unless association.embedded?
              if keys
                collection << name
              else
                collection[name] = doc.send(name)
              end
            end
            collection
          end
        end
      end
    end
  end
end