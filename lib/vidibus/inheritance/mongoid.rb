module Vidibus
  module Inheritance
    module Mongoid
      extend ActiveSupport::Concern

      ACQUIRED_ATTRIBUTES = %w[_id uuid ancestor_uuid mutated_attributes _documents_count created_at updated_at version versions]
      
      included do
        attr_accessor :inherited_attributes
        attr_accessor :_changed
        
        field :ancestor_uuid
        
        attr_protected :_documents_count, :mutated_attributes
        field :_documents_count, :type => Integer, :default => 0
        field :mutated_attributes, :type => Array, :default => []

        validates :ancestor_uuid, :uuid => { :allow_blank => true }
        validates :ancestor, :ancestor => true, :if => :ancestor_uuid?
        
        before_validation :preprocess        
        after_save :postprocess
        # after_save :inherit_documents, :if => :embed?
        # after_update :update_inheritors
        
        # after_create :notify_parent
        
        #after_create :notify_parent, :if => :embedded?

        protected
        
        attr_accessor :_inherited
        attr_accessor :_changed
        attr_accessor :_skip_callbacks
      end
      
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
      def inherit!(options = {})
        # puts "inherit!"
        self.inherit_attributes(options)
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
      
      # Returns list of objects that inherit from this ancestor.
      def inheritors
        self.class.where(:ancestor_uuid => uuid).all.to_a
      end
      
      protected
      
      def preprocess
        # return if _skip_callbacks
        track_mutations
        # track_document_changes if embed?
        inherit_attributes if inherit?
      end
      
      def postprocess
        # return if _skip_callbacks
        # if embed?
        #   inherit_documents
        #   track_document_changes
        #   if _documents_count_changed?
        #     update_without_callbacks
        #   end
        # end
        inherit_documents if embed?
        update_inheritors
      end
      
      # def update_without_callbacks
      #   puts '######################### update_without_callbacks: '+_id.to_s
      #   self._skip_callbacks = true
      #   update
      #   self._skip_callbacks = nil
      # end
      
      # Returns true if inheritance should be applied on inheritor.
      def inherit?
        !_inherited and ancestor and (new_record? or ancestor_uuid_changed?)
      end
      
      # Performs inheritance while excluding acquired and mutated attributes.
      # Accepts :reset option to overwrite mutated attributes.
      # 
      # Usage:
      #
      #   inherit_attributes(:reset => true)          => # Overwrites all mutated at§tributes
      #   inherit_attributes(:reset => :name)         => # Overwrites name only
      #   inherit_attributes(:reset => [:name, :age]) => # Overwrites name and age
      #
      def inherit_attributes(options = {})
        # puts "inherit_attributes"
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
      
      # Returns embedded documents.
      def inheritable_documents
        #@inheritable_documents ||= 
        begin
          list = {}
          for name, association in associations
            next unless association.embedded?
            list[name] = send(name)
          end
          list
        end
      end
      
      def embed?
        inheritable_documents.any?
      end
      
      # Stores changed attributes.
      # Sets _changed to true if aquired attributes have been changed recently.
      def track_mutations
        # puts "track_mutations of #{_id}"
        changed_items = new_record? ? attributes.keys : changes.keys
        changed_items -= ACQUIRED_ATTRIBUTES
        self._changed = changed_items.any?
        if inherited_attributes
          changed_items -= inherited_attributes.keys
          self.inherited_attributes = nil
        end
        self.mutated_attributes += changed_items
        self.mutated_attributes.uniq!
      end
      
      # # Detects changes of inheritable documents.
      # # Sets _changed to true if children attributes have been changed recently.
      # # Stores _documents_count.
      # def track_document_changes
      #   changed_items = []
      #   if list = inheritable_documents
      #     documents_count = 0
      #     for association, inheritable in list
      #       next unless inheritable
      #       if inheritable.is_a?(Array)
      #         for obj in inheritable
      #           changed_items << obj._id if obj.changed?
      #           documents_count += 1
      #         end
      #       else
      #         changed_items << inheritable._id if inheritable.changed?
      #         documents_count += 1
      #       end
      #     end
      #   end
      #   
      #   puts "documents_count = #{documents_count.inspect}"
      #   puts "_documents_count = #{_documents_count.inspect}"
      # 
      #   if documents_count and documents_count != _documents_count
      #     self._changed = true
      #     self._documents_count = documents_count
      #   elsif changed_items.any?
      #     self._changed = true
      #   end
      # end
      
      # Walk all associations of ancestor
      # For each object
      #   check if it is present for inheritor.
      #     If it is missing,
      #       and inheritance is supported, create a new inheritor of the association
      #       or simply create a new object with given attributes.
      #     If it is present,
      #       and it has been changed
      # 
      # Track changes, somehow
      # 
      def inherit_documents
        return unless ancestor
        return unless list = ancestor.reload.inheritable_documents
        # puts ">>>> inherit_documents on #{_id}: #{list.inspect}"
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
                existing = collection.where(:_reference_id => obj._id).first
                update_inheritable_document(existing, attrs)
              else
                collection.create!(attrs)
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
              if existing = self.send("#{association}")
                update_inheritable_document(existing, attrs)
              else
                self.send("create_#{association}", attrs)
              end
            elsif existing = self.send("#{association}")
              existing.destroy
            end
          end
        end
      end
      
      def update_inheritable_document(doc, attrs)
        if doc.respond_to?(:update_inheritance?)
          if doc.update_inheritance?(attrs) == true
            doc.update_attributes(attrs)
          end
        else
          doc.update_attributes(attrs)
        end
      end
      
      # Returns list of inheritable attributes of a document.
      # The list will include the given object as ancestor if it supports inheritance.
      def inheritable_document_attributes(obj)
        attrs = obj.attributes.except(*ACQUIRED_ATTRIBUTES)
        attrs[:_reference_id] = obj._id
        attrs
      end
      
      # Applies changes to inheritors.
      def update_inheritors
        return unless inheritors.any?
        # puts "#{_id}: update_inheritors"
        inheritors.each(&:inherit!)
      end
    end
  end
end