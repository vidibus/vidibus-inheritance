module Vidibus
  module Inheritance
    module Mongoid
      extend ActiveSupport::Concern
      
      ACQUIRED_ATTRIBUTES = %w[_id _type uuid ancestor_uuid root_ancestor_uuid mutated_attributes mutated created_at updated_at version versions]
      
      included do
        
        # To define additional aquired attributes on your model, set @@acquired_attributes on it.
        #@@aquired_attributes = nil
        
        attr_accessor :inherited_attributes, :_inherited
        attr_protected :mutated_attributes, :mutated
        
        field :ancestor_uuid
        field :root_ancestor_uuid
        field :mutated_attributes, :type => Array, :default => []
        field :mutated, :type => Boolean
        
        validates :ancestor_uuid, :uuid => { :allow_blank => true }
        validates :root_ancestor_uuid, :uuid => { :allow_blank => true }
        validates :ancestor, :ancestor => true, :if => :ancestor_uuid?
        validates :root_ancestor, :ancestor => true, :if => :root_ancestor_uuid?

        set_callback :validate, :before, :inherit_attributes, :if => :inherit?
        set_callback :save, :before, :track_mutations, :set_root_ancestor, :unless => :skip_inheritance?
        set_callback :save, :after, :postprocess, :unless => :skip_inheritance?
        set_callback :destroy, :after, :destroy_inheritors
        
        # Returns true if attributes have been mutated.
        # This method must be included directly so that it will not be
        # overwritten by Mongoid's accessor #mutated?
        def mutated?
          @is_mutated ||= mutated || mutated_attributes.any?
        end
      end
      
      module ClassMethods
        
        # Returns embedded documents of given document.
        # Provide :keys option if you want to return a list of document types instead
        # of a hash of documents grouped by their type.
        #
        # Example:
        #
        #   inheritable_documents(model)
        #   # => { :children => [ <embeds_many collection> ], :location => <embeds_one object> }
        #
        #   inheritable_documents(model, :keys => true)
        #   # => [:children, :location ]
        #
        def inheritable_documents(object, options = {})
          keys = options[:keys]
          collection = keys ? [] : {}
          for name, association in object.associations
            next unless association.embedded?
            if keys
              collection << name
            else
              collection[name] = object.send(name)
            end
          end
          collection
        end
        
        # Returns all objects that have no ancestor.
        # Accepts Mongoid criteria to reduce and sort matching set.
        # Criteria API: http://mongoid.org/docs/querying/
        #
        # Examples:
        #   
        #   Model.roots                          # => All models without ancestor
        #   Model.roots.where(:name => "Laura")  # => Only models named Laura
        #   Model.roots.asc(:created_at)         # => All models, ordered by date of creation
        # 
        def roots
          where(:ancestor_uuid => nil)
        end
      end
    
      # Setter for ancestor.
      def ancestor=(obj)
        self.ancestor_uuid = obj ? obj.uuid : nil
        @ancestor = obj
      end
    
      # Returns ancestor object by uuid.
      def ancestor
        @ancestor ||= begin
          self.class.where(:uuid => ancestor_uuid).first if ancestor_uuid
        end
      end
      
      # Returns a list of all ancestors ordered by inheritance distance.
      def ancestors
        @ancestors ||= [].tap do |bloodline|
          obj = self
          while true do
            break unless obj = obj.ancestor
            bloodline << obj
          end
        end
      end
      
      # Returns root ancestor object by uuid.
      def root_ancestor
        @root_ancestor ||= begin
          self.class.where(:uuid => root_ancestor_uuid).first if root_ancestor_uuid
        end
      end
      
      # Performs inheritance and saves instance with force.
      # Accepts :reset option to overwrite mutated attributes.
      # 
      # Examples:
      #
      #   inherit!(:reset => true)          => # Overwrites all mutated attributes
      #   inherit!(:reset => :name)         => # Overwrites name only
      #   inherit!(:reset => [:name, :age]) => # Overwrites name and age
      #
      def inherit!(options = {})
        inherit_attributes(options)
        self.save!
      end
    
      # Performs inheritance from given object and returns self.
      # It sets the ancestor and then calls #inherit! with given options.
      def inherit_from!(obj, options = {})
        self.ancestor = obj
        self.inherit!(options)
        self
      end
    
      # Returns inheritors of this ancestor.
      def inheritors
        self.class.where(:ancestor_uuid => uuid)
      end
    
      # Returns embedded documents.
      # See ClassMethods.inheritable_documents for options.
      def inheritable_documents(options = {})
        self.class.inheritable_documents(self, options)
      end
      
      # Creates a sibling with identical inheritable attributes.
      # First it inherits from self and then applies ancestry of self.
      def clone!
        clone = self.class.new
        clone.inherit_from!(self)
        clone.ancestor = ancestor
        clone.mutated_attributes = mutated_attributes
        clone.inherited_attributes = inherited_attributes
        clone.save!
        clone
      end
      
      # Returns acquired attributes.
      # Overwrite this method to define custom ones.
      def acquired_attributes
        ACQUIRED_ATTRIBUTES
      end
      
      private
    
      # Performs inheritance of attributes while excluding acquired and mutated ones.
      # Accepts :reset option to overwrite mutated attributes.
      def inherit_attributes(options = {})
        track_mutations
        self._inherited = true
        exceptions = self.acquired_attributes
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
            existing_ids = collection.map { |a| a.try!(:_reference_id) }
            
            obsolete = (existing_ids - inheritable.map { |i| i._id }).compact
            obsolete -= collection.select do |c| 
              obsolete.include?(c.try!(:_reference_id)) and c.try!(:mutated?) # Exclude mutated items
            end.map { |c| c.try!(:_reference_id) }
            if obsolete.any?
              collection.delete_all(:conditions => { :_reference_id.in => obsolete })
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
      
      # Performs actions after saving.
      def postprocess
        if inheritor?
          inherit_documents if embed?
          # TODO: allow real callbacks
          try!(:after_inheriting)
        end
        update_inheritors
      end
      
      # Returns true if object is an inheritor.
      def inheritor?
        ancestor
      end
      
      # Returns true if inheritance should be applied on inheritor.
      def inherit?
        !_inherited and ancestor and (new_record? or ancestor_uuid_changed?)
      end
      
      def skip_inheritance?
        @skip_inheritance
      end
      
      # Returns true if this documents has any inheritable documents.
      def embed?
        inheritable_documents.any?
      end

      # Stores changed attributes as #mutated_attributes unless they have been inherited recently.
      def track_mutations
        changed_items = new_record? ? attributes.keys : changes.keys
        changed_items -= self.acquired_attributes
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
        # puts "doc = #{doc.inspect}"
        # puts "doc.acquired_attributes = #{doc.acquired_attributes.inspect}"
        # puts "doc.try!(:acquired_attributes) = #{doc.try!(:acquired_attributes).inspect}"
        exceptions = doc.try!(:acquired_attributes) || ACQUIRED_ATTRIBUTES
        attrs = doc.attributes.except(*exceptions)
        attrs[:_reference_id] = doc._id
        attrs
      end
      
      # Applies changes to inheritors.
      def update_inheritors
        return unless inheritors.any?
        inheritors.each(&:inherit!)
      end
      
      # Destroys inheritors.
      def destroy_inheritors
        return unless inheritors.any?
        inheritors.each(&:destroy)
      end
      
      # Sets root ancestor from ancestor:
      # If ancestor is the root ancestor, he will be set.
      # If ancestor has an ancestor himself, his root ancestor will be set.
      def set_root_ancestor
        @root_ancestor = nil # reset cache
        if !ancestor_uuid
          self.root_ancestor_uuid = nil
        elsif ancestor and !ancestor.ancestor_uuid
          self.root_ancestor_uuid = ancestor_uuid
        else
          self.root_ancestor_uuid = ancestor.root_ancestor_uuid
        end
      end
    end
  end
end