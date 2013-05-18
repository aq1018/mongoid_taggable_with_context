module Mongoid::TaggableWithContext
  extend ActiveSupport::Concern

  class AggregationStrategyMissing < Exception; end
  class InvalidTagsFormat < Exception; end

  DEFAULT_FIELD = :tags
  DEFAULT_SEPARATOR = ' '

  included do
    class_attribute :taggable_with_context_options
    self.taggable_with_context_options = {}
  end

  def tags_string_for(context)
    self.read_attribute(context).join(self.class.get_tag_separator_for(context))
  end

  module ClassMethods
    # Macro to declare a document class as taggable, specify field name
    # for tags, and set options for tagging behavior.
    #
    # @example Define a taggable document.
    #
    #   class Article
    #     include Mongoid::Document
    #     include Mongoid::TaggableWithContext
    #     taggable :keywords, separator: ' ', default: ['foobar']
    #   end
    #
    # @param [ Symbol ] field The name of the field for tags.
    # @param [ Hash ] options Options for taggable behavior.
    #
    # @option options [ String ] :separator
    #   The delimiter used when converting the tags to and from String format. Defaults to ' '
    # @option options [ <various> ] :default, :as, :localize, etc.
    #   Options for Mongoid #field method will be automatically passed
    #   to the underlying Array field
    def taggable(*args)
      # init variables
      options = args.extract_options!

      raise 'taggable :field option has been removed as of version 1.1.0. Please use the syntax "taggable <database_name>, as: <tag_name>"' if options[:field]
      raise 'taggable :string_method option has been removed as of version 1.1.0. Please define an alias to "<tags>_string"' if options[:string_method]

      # db_field: the field name stored in the database
      options[:db_field] = args.present? ? args.shift.to_sym : DEFAULT_FIELD

      # field: the field name used to identify the tags. :field will
      # be identical to :db_field unless the :as option is specified
      options[:field] = options[:as] || options[:db_field]

      options.reverse_merge!(separator: DEFAULT_SEPARATOR)

      # register / update settings
      self.taggable_with_context_options[options[:field]] = options

      # setup fields & indexes
      field options[:db_field], mongoid_field_options(options)

      index({ options[:field] => 1 }, { background: true })

      # singleton methods
      self.class.class_eval do
        # retrieve all tags ever created for the model
        define_method options[:field] do
          tags_for(options[:field])
        end

        # retrieve all tags ever created for the model with weights
        define_method :"#{options[:field]}_with_weight" do
          tags_with_weight_for(options[:field])
        end

        define_method :"#{options[:field]}_separator" do
          get_tag_separator_for(options[:field])
        end

        define_method :"#{options[:field]}_tagged_with" do |tags|
          tagged_with(options[:field], tags)
        end
      end

      #instance methods
      class_eval do
        define_method :"#{options[:field]}_string" do
          tags_string_for(options[:field])
        end

        define_method :"#{options[:field]}=" do |value|
          write_attribute(options[:field], self.class.format_tags_for(options[:field], value))
        end
      end
    end

    def tag_contexts
      self.taggable_with_context_options.keys
    end

    def tag_database_fields
      self.taggable_with_context_options.keys.map do |context|
        tag_options_for(context)[:db_field]
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
      tags = format_tags_for(context, tags)
      field = tag_options_for(context)[:field]
      all_in(field => tags)
    end

    # Helper method to convert a a tag input value of unknown type
    # to a formatted array.
    def format_tags_for(context, value)
      # 0) Tags must be an array or a string
      raise InvalidTagsFormat unless value.is_a?(Array) || value.is_a?(String)
      # 1) convert String to Array
      value = value.split(get_tag_separator_for(context)) if value.is_a? String
      # 2) remove all nil values
      # 3) strip all white spaces. Could leave blank strings (e.g. foo, , bar, baz)
      # 4) remove all blank strings
      # 5) remove duplicate
      value.compact.map(&:strip).reject(&:blank?).uniq
    end

    protected

    # Prepares valid Mongoid option keys from the taggable options
    # @param [ Hash ] :options The taggable options hash.
    # @return [ Hash ] A options hash for the Mongoid #field method.
    def mongoid_field_options(options = {})
      options.slice(*::Mongoid::Fields::Validators::Macro::OPTIONS).merge!(type: Array)
    end
  end
end
