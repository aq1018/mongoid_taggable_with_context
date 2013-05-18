module Mongoid::TaggableWithContext
  extend ActiveSupport::Concern

  class AggregationStrategyMissing < Exception; end

  DEFAULT_FIELD = :tags
  DEFAULT_SEPARATOR = ' '

  included do
    class_attribute :taggable_with_context_options
    self.taggable_with_context_options = {}
    delegate 'convert_string_to_array',        to: 'self.class'
    delegate 'convert_array_to_string',        to: 'self.class'
    delegate 'clean_up_array',                 to: 'self.class'
    delegate 'get_tag_separator_for',          to: 'self.class'
    delegate 'format_tags_for_write',          to: 'self.class'
    delegate 'tag_contexts',                   to: 'self.class'
    delegate 'tag_options_for',                to: 'self.class'
    delegate 'tag_database_fields',            to: 'self.class'
  end

  def tags_string_for(context)
    convert_array_to_string(self.read_attribute(context), get_tag_separator_for(context))
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
    #   The tag separator to convert from. Defaults to ' '
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

        define_method :"#{options[:field]}_separator=" do |value|
          set_tag_separator_for(options[:field], value)
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
          write_attribute(options[:field], format_tags_for_write(value, get_tag_separator_for(options[:field])))
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

    def set_tag_separator_for(context, value)
      self.taggable_with_context_options[context][:separator] = value.nil? ? DEFAULT_SEPARATOR : value.to_s
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
      field = tag_options_for(context)[:field]
      all_in(field => tags)
    end

    # Helper method to convert a a tag input value of unknown type
    # to a formatted array.
    def format_tags_for_write(value, separator = DEFAULT_SEPARATOR)
      if value.is_a? Array
        clean_up_array(value)
      else
        convert_string_to_array(value, separator)
      end
    end

    # Helper method to convert a String to an Array based on the
    # configured tag separator.
    def convert_string_to_array(str = '', separator = DEFAULT_SEPARATOR)
      clean_up_array(str.split(separator))
    end

    def convert_array_to_string(ary = [], separator = DEFAULT_SEPARATOR)
      ary.join(separator)
    end

    def clean_up_array(ary = [])
      # 0). remove all nil values
      # 1). strip all white spaces. Could leave blank strings (e.g. foo, , bar, baz)
      # 2). remove all blank strings
      # 3). remove duplicate
      ary.compact.map(&:strip).reject(&:blank?).uniq
    end

    # Prepares valid Mongoid option keys from the taggable options
    # @param [ Hash ] :options The taggable options hash.
    # @return [ Hash ] A options hash for the Mongoid #field method.
    def mongoid_field_options(options = {})
      options.slice(*::Mongoid::Fields::Validators::Macro::OPTIONS).merge!(type: Array)
    end
  end
end
