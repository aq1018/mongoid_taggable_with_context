module Mongoid::TaggableWithContext
  extend ActiveSupport::Concern

  class AggregationStrategyMissing < Exception; end

  TAGGABLE_DEFAULT_SEPARATOR = ' '

  included do
    class_attribute :taggable_with_context_options
    class_attribute :context_array_to_context_hash
    self.taggable_with_context_options = {}
    self.context_array_to_context_hash = {}
    delegate "convert_string_to_array",       :to => 'self.class'
    delegate "convert_array_to_string",       :to => 'self.class'
    delegate "clean_up_array",                :to => 'self.class'
    delegate "get_tag_separator_for",         :to => 'self.class'
    delegate "format_tags_for_write",         :to => 'self.class'
    delegate "tag_contexts",                  :to => 'self.class'
    delegate "tag_options_for",               :to => 'self.class'
    delegate "tag_array_attributes",          :to => 'self.class'
    delegate "context_array_to_context_hash", :to => 'self.class'
  end

  module ClassMethods
    # Macro to declare a document class as taggable, specify field name
    # for tags, and set options for tagging behavior.
    #
    # @example Define a taggable document.
    #
    #   class Article
    #     include Mongoid::Document
    #     include Mongoid::Taggable
    #     taggable :keywords, :separator => ' ', :aggregation => true, :default_type => "seo"
    #   end
    #
    # @param [ Symbol ] field The name of the field for tags.
    # @param [ Hash ] options Options for taggable behavior.
    #
    # @option options [ String ] :separator The tag separator to
    #   convert from; defaults to ','
    # @option options [ true, false ] :aggregation Whether or not to
    #   aggregate counts of tags within the document collection using
    #   map/reduce; defaults to false
    # @option options [ String ] :default_type The default type of the tag.
    #   Each tag can optionally have a tag type. The default type is nil
    def taggable(*args)
      # init variables
      options = args.extract_options!
      tags_field = (args.blank? ? :tags : args.shift).to_sym
      options.reverse_merge!(
        :separator => TAGGABLE_DEFAULT_SEPARATOR,
        :array_field => "#{tags_field}_array".to_sym
      )
      tags_array_field = options[:array_field]

      # register / update settings
      self.taggable_with_context_options[tags_field] = options
      self.context_array_to_context_hash[options[:array_field]] = tags_field 

      # setup fields & indexes
      field tags_array_field, :type => Array, :default => options[:default]
      # deprecated: index tags_array_field
      # Invalid index specification on Category: tags_array, {}

      index({ tags_array_field => 1 }, { background: true })

      # singleton methods
      class_eval <<-END
        class << self
          # retrieve all tags ever created for the model
          def #{tags_field}
            tags_for(:"#{tags_field}")
          end

          # retrieve all tags ever created for the model with weights
          def #{tags_field}_with_weight
            tags_with_weight_for(:"#{tags_field}")
          end

          def #{tags_field}_separator
            get_tag_separator_for(:"#{tags_field}")
          end

          def #{tags_field}_separator=(value)
            set_tag_separator_for(:"#{tags_field}", value)
          end

          def #{tags_field}_tagged_with(tags)
            tagged_with(:"#{tags_field}", tags)
          end
        end
      END

      # instance methods
      class_eval <<-END
        def #{tags_field}
          convert_array_to_string(#{tags_array_field}, get_tag_separator_for(:"#{tags_field}"))
        end
        def #{tags_field}=(value)
          write_attribute(:#{tags_array_field}, format_tags_for_write(value, get_tag_separator_for(:"#{tags_field}")))
        end
        alias_method :#{tags_array_field}=, :#{tags_field}=
      END
    end

    def tag_contexts
      self.taggable_with_context_options.keys
    end
    
    def tag_array_attributes
      self.taggable_with_context_options.keys.map do |context|
        tag_options_for(context)[:array_field]
      end
    end

    def tag_options_for(context)
      self.taggable_with_context_options[context]
    end

    def tags_for(context, conditions={})
      raise AggregationStrategyMissing
    end

    def tags_with_weight_for(context, conditions={})
      raise AggregationStrategyMissing
    end

    def get_tag_separator_for(context)
      self.taggable_with_context_options[context][:separator]
    end

    def set_tag_separator_for(context, value)
      self.taggable_with_context_options[context][:separator] = value.nil? ? TAGGABLE_DEFAULT_SEPARATOR : value.to_s
    end

    # Find documents tagged with all tags passed as a parameter, given
    # as an Array or a String using the configured separator.
    #
    # @example Find matching all tags in an Array.
    #   Article.tagged_with(['ruby', 'mongodb'])
    # @example Find matching all tags in a String.
    #   Article.tagged_with('ruby, mongodb')
    #
    # @param [ String ] :field The field name of the tag.
    # @param [ Array<String, Symbol>, String ] :tags Tags to match.
    # @return [ Criteria ] A new criteria.
    def tagged_with(context, tags)
      tags = convert_string_to_array(tags, get_tag_separator_for(context)) if tags.is_a? String
      array_field = tag_options_for(context)[:array_field]
      all_in(array_field => tags)
    end

    # Helper method to convert a a tag input value of unknown type
    # to a formatted array.
    def format_tags_for_write(value, separator = TAGGABLE_DEFAULT_SEPARATOR)
      if value.is_a? Array
        clean_up_array(value)
      else
        convert_string_to_array(value, separator)
      end
    end

    # Helper method to convert a String to an Array based on the
    # configured tag separator.
    def convert_string_to_array(str = "", separator = TAGGABLE_DEFAULT_SEPARATOR)
      clean_up_array(str.split(separator))
    end

    def convert_array_to_string(ary = [], separator = TAGGABLE_DEFAULT_SEPARATOR)
      #ary.join(separator)
      (ary || []).join(separator)
    end

    def clean_up_array(ary = [])
      # 0). remove all nil values
      # 1). strip all white spaces. Could leave blank strings (e.g. foo, , bar, baz)
      # 2). remove all blank strings
      # 3). remove duplicate
      ary.compact.map(&:strip).reject(&:blank?).uniq
    end

  end
end
