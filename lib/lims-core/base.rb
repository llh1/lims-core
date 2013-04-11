# vi: ts=2 sts=2 et sw=2 spell spelllang=en  
require 'common'
require 'lims-core/container'

module Lims::Core
  module Base
    def self.included(klass)
      klass.class_eval do
        include Virtus
        include Virtus::Dirty
        include Aequitas
        include AccessibleViaSuper
        extend Forwardable
        extend ClassMethod
      end
    end


    module Virtus::Dirty
      def self.included(klass)
        klass.class_eval do
          include ActiveModel::Dirty
        end
      end

      def setup_dirty_tracking
        bind_virtus_to_dirty_tracking 
        redefine_writers_with_dirty_tracking
      end

      def start_dirty_tracking
        @dirty_tracking_started = true
      end

      def dirty_attributes_tracked?
        @dirty_tracking_started
      end

      def stop_dirty_tracking
        @dirty_tracking_started = false
        clear_dirty_tracking
      end

      private

      # @changed_attributes is a public instance
      # variable from ActiveModel::Dirty. We clear it
      # to erase the dirty status of an object.
      def clear_dirty_tracking
        @changed_attributes.clear
      end

      # Using ActiveModel::Dirty, we need to pass to the method
      # 'define_attribute_methods' each method we want to track.
      # We pass it all the virtus attributes.
      def bind_virtus_to_dirty_tracking
        virtus_attributes = self.attributes.keys
        self.class.class_eval do
          define_attribute_methods(virtus_attributes)
        end
      end

      # Before each change of the tracked attribute, we need 
      # to call the ActiveModel::Dirty#attribute_will_change! method.
      # We rewrite below the writer method for each virtus attributes
      # which call the original writer method and call the 
      # attribute_will_change! method only if the value received by the
      # writer is a new value.
      def redefine_writers_with_dirty_tracking
        self.attributes.each do |attribute, value|
          method = "#{attribute}=".to_sym
          method_alias = "__#{method.to_s}_alias__".to_sym

          self.class.class_eval do
            next if private_instance_methods.include?(method_alias)
            alias_method method_alias, method 
            private method_alias

            # After we redefine the method, we should set 
            # the same visibility as before.
            original_method_private = private_instance_methods.include?(method)
            define_method(method) do |*args|
              previous_value = __send__(attribute)
              __send__("#{attribute}_will_change!") unless args.first == previous_value 
              result = __send__(method_alias, *args)
            end
            private method if original_method_private
          end
        end
      end
    end


    module AccessibleViaSuper
      def initialize(*args, &block)
        setup_dirty_tracking
        # readonly attributes are normaly not allowed in constructor
        # by Virtus. We need to call set_attributes explicitely
        options = args.extract_options!
        # we would use `options & [:row ... ]` if we could
        # but Sequel redefine Hash#& ...
        initializables = self.class.attributes.select {|a| a.options[:initializable] == true  }
        initial_options  = options.subset(initializables.map(&:name))
        set_attributes(initial_options)
        super(*args, options - initial_options, &block).tap {
        }
      end
    end
    # Compare 2 resources.
    # They are == if they have the same values (attributes),
    # regardless they are the same ruby object or not.
    # @param other
    # @return [Boolean]
    def ==(other)
      self.attributes == (other.respond(:attributes) || {} )
    end


    module ClassMethod
      def is_array_of(child_klass, options = {},  &initializer)
        define_method :initialize_array do |*args|
          @content = initializer ? initializer[self, child_klass] : []
        end

        class_eval do
          include Enumerable
          include IsArrayOf
          def_delegators :@content, :each, :size , :each_with_index, :map, :zip, :clear, :empty?, :to_s \
            , :include?, :to_a, :first, :last

        end
      end

      def is_matrix_of(child_klass, options = {},  &initializer)
        element_name = child_klass.name.split('::').last.downcase
        class_eval do
          is_array_of(child_klass, options, &initializer)
          include Container

          define_method "get_#{element_name}" do |*args|
            get_element(*args)
          end

        end
      end
    end


    module IsArrayOf

      def initialize(*args, &block)
        super(*args, &block)
        initialize_array()
      end

      # Add content to compare
      # If classe are not in the same hierarchy we only compare the content
      # @param other to compare with
      # @return [Boolean]
      def ==(other)
        if other.is_a?(self.class) || self.is_a?(other.class)
          super(other)
        else
          true
        end && self.to_a == other.to_a
      end

      # The underlying array. Use to everything which is not directly delegated 
      # @return [Array]
      def content
        @content 
      end

      # Delegate [] to the underlying array.
      # This is needed because Virtus redefine [] as well 
      # @param [Fixnum, ... ] i index
      # @return [Object]
      def [](i)
        case i
        when Fixnum then self.content[i]
        else super(i)
        end
      end

      def []=(i, value)
        case i
        when Fixnum then self.content[i]=value
        else super(i, value)
        end
      end
      # iterate only between non empty lanes.
      # @yield [content]
      # @return itself
      def each_content
        @content.each do |content|
          yield content if content
        end
      end
    end 

    class HashString < Virtus::Attribute::Object
      primitive Hash
      def coerce(hash)
        hash.rekey  {|key| key.to_s }
      end
    end

    # @todo override state_machine to automatically add
    # attribute
    class State < Virtus::Attribute::Object
      primitive String
    end
  end
end
