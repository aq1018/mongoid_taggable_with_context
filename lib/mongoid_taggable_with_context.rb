# Copyright (c) 2010 Wilker Lúcio <wilkerlucio@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Mongoid::TaggableWithContext
  extend ActiveSupport::Concern

  included do
    class_inheritable_reader :taggable_with_context_options
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
        :separator => ' ',
        :array_field => "#{tags_field}_array".to_sym
      )
      tags_array_field = options[:array_field]
      first_invoke = taggable_with_context_options.nil?
      
      # register / update settings
      class_options = taggable_with_context_options || {}
      class_options[tags_field] = options
      write_inheritable_attribute(:taggable_with_context_options, class_options)
      
      # setup fields & indexes
      field tags_field
      field tags_array_field, :type => Array
      index tags_array_field

      if first_invoke
        delegate "convert_string_to_array", :to => 'self.class'
        delegate "convert_array_to_string", :to => 'self.class'
        delegate "tag_separator_for",       :to => 'self.class'
        
        set_callback :save,     :after, :update_tags_aggregation
        set_callback :create,   :after, :increment_tags_aggregation
        set_callback :destroy,  :after, :decrement_tags_aggregation
      end
      
      extend SingletonMethods
      include InstanceMethods
      
      # singleton methods
      class_eval <<-END
        class << self
          def #{tags_field}_aggregation_collection
            @#{tags_field}_aggregation_collection ||= aggregation_collection_for(:"#{tags_field}")
          end
    
          def #{tags_field}
            tags_for(:"#{tags_field}")
          end
      
          def #{tags_field}_with_weight
            tags_with_weight_for(:"#{tags_field}")
          end
      
          def #{tags_field}_separator
            tag_separator_for(:"#{tags_field}")
          end
                  
          def #{tags_field}_tagged_with(tags)
            tagged_with(:"#{tags_field}", tags)
          end
        end
      END
      
      # instance methods
      class_eval <<-END
        def #{tags_field}=(s)
          super
          write_attribute(:#{tags_array_field}, convert_string_to_array(s, tag_separator_for(:"#{tags_field}")))
        end
        
        def #{tags_array_field}=(a)
          super
          write_attribute(:#{tags_field}, convert_array_to_string(a, tag_separator_for(:"#{tags_field}")))
        end
      END
    end
  end
  
  module SingletonMethods
    def tag_contexts
      taggable_with_context_options.keys
    end
    
    def tag_options_for(context)
      taggable_with_context_options[context]
    end
    
    # Collection name for storing results of tag count aggregation
    def aggregation_collection_for(context)
      "#{collection_name}_#{context}_aggregation"
    end

    def tags_for(context)
      db.collection(aggregation_collection_for(context)).find.to_a.map{ |t| t["_id"] }
    end
    
    # retrieve the list of tag with weight(count), this is useful for
    # creating tag clouds
    def tags_with_weight_for(context)
      db.collection(aggregation_collection_for(context)).find.to_a.map{ |t| [t["_id"], t["value"]] }
    end
  
    def tag_seperator_for(context)
      taggable_with_context_options[context][:separator]
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
      tags = convert_string_to_array(tags, tag_seperator_for(context)) if tags.is_a? String
      criteria.all_in(context => tags)
    end
  
    # Helper method to convert a String to an Array based on the
    # configured tag separator.
    def convert_string_to_array(str, seperator = " ")
      str.split(seperator).map(&:strip)
    end
  
    def convert_array_to_string(ary, seperator = " ")
      ary.join(seperator)
    end
  end
  
  module InstanceMethods
    def need_update_tags_aggregation?
      !changed_contexts.empty?
    end
    
    def changed_contexts
      tag_contexts & previous_changes.keys.map(&:to_sym)
    end
    
    def increment_tags_aggregation
      tag_contexts.each do |context|
        field_name = tag_options_for(context)[:array_field]
        tags = self.send field_name
        coll = db.collection(aggregation_collection_for(context))
        tags.each do |t|
          coll.update({:name => t}, {'$inc' => {:count => 1}}, :upsert => true)
        end
      end
    end
    
    def decrement_tags_aggregation
      tag_contexts.each do |context|
        coll = db.collection(aggregation_collection_for(context))
        field_name = tag_options_for(context)[:array_field]
        tags = self.send field_name
        tags.each do |t|
          coll.update({:name => t}, {'$inc' => {:count => -1}}, :upsert => true)
        end
      end
    end
    
    def update_tags_aggregation
      return unless need_update_tags_aggregation?
      
      changed_contexts.each do |context|
        coll = db.collection(aggregation_collection_for(context))
        field_name = tag_options_for(context)[:array_field]        
        old_tags, new_tags = previous_changes["#{field_name}"]
        old_tags ||= []
        new_tags ||= []
        unchanged_tags = old_tags & new_tags
        tags_removed = old_tags - unchanged_tags
        tags_added = new_tags - unchanged_tags
        
        tags_removed.each do |t|
          coll.update({:name => t}, {'$inc' => {:count => -1}}, :upsert => true)
        end
        
        tags_added.each do |t|
          coll.update({:name => t}, {'$inc' => {:count => 1}}, :upsert => true)
        end
      end
    end
  end
end
