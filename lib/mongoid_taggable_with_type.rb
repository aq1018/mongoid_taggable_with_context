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

module Mongoid::TaggableWithType
  extend ActiveSupport::Concern

  included do
    class_inheritable_reader :taggable_with_type_options
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
      options = args.extract_options!
      
      tags_field = (args.blank? ? :tags : args.shift).to_sym
      tags_array_field = "#{tags_field}_array".to_sym

      options.reverse_merge!(
        :separator => ' ',
        :aggregation => true,
        :default_type => nil,
        :array_field => tags_array_field
      )
      
      class_options = taggable_with_type_options || {}
      class_options[tags_field] = options
      write_inheritable_attribute(:taggable_with_type_options, class_options)
      
      field tags_field
      field options[:array_field], :type => Array
      index options[:array_field]
      
      delegate "convert_string_#{tags_field}_to_array", :to => 'self.class'
      delegate "convert_array_#{tags_field}_to_string", :to => 'self.class'
      
      class_eval <<-END
        set_callback :save, :after, :if => proc { should_update_#{tags_field}_aggregation? } do |document|
          document.class.aggregate_#{tags_field}!
        end
      END
      
      # singleton methods
      class < self
        class_eval <<-END
          # Collection name for storing results of tag count aggregation
          def #{tags_field}_aggregation_collection
            @#{tags_field}_aggregation_collection ||= "#{collection_name}_#{tags_field}_aggregation"
          end
      
          def #{tags_field}
            db.collection(#{tags_field}_aggregation_collection).find.to_a.map{ |r| r["_id"] }
          end
        
          # retrieve the list of tag with weight(count), this is useful for
          # creating tag clouds
          def #{tags_field}_with_weight
            db.collection(#{tags_field}_aggregation_collection).find.to_a.map{ |r| [r["_id"], r["value"]] }
          end
        
          # Predicate for whether or not map/reduce aggregation is enabled
          def aggregate_#{tags_field}?
            !!taggable_with_type_options[:#{tags_field}][:aggregation]
          end
          
          def #{tags_field}_seperator
            taggable_with_type_options[:#{tags_field}][:seperator]
          end
          
          def #{tags_field}_default_type
            taggable_with_type_options[:#{tags_field}][:default_type]
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
          def #{tags_field}_tagged_with(tags)
            tags = convert_string_#{tags_field}_to_array(tags) if tags.is_a? String
            criteria.all_in(:#{tags_field} => tags)
          end
          
          private
          # Helper method to convert a String to an Array based on the
          # configured tag separator.
          def convert_string_#{tags_field}_to_array(s)
            (s).split(#{tags_field}_seperator).map(&:strip)
          end
          
          def convert_array_#{tags_field}_to_string(a)
            a.join(#{tags_field}_seperator)
          end
        END
      end
      
      # instance methods
      class_eval <<-END
        private
        
        # Execute map/reduce operation to aggregate tag counts for document
        # class
        def aggregate_#{tags_field}!
          return unless aggregate_#{tags_field}?

          map = "function() {
            if (!this.#{tags_field}) {
              return;
            }

            for (index in this.#{tags_field}) {
              emit(this.#{tags_field}[index], 1);
            }
          }"

          reduce = "function(tag_name, values) {
            var count = 0;

            for (index in values) {
              count += values[index]
            }

            return count;
          }"

          collection.master.map_reduce(map, reduce, :out => #{tags_field}_aggregation_collection)
        end
        
        # Guard for callback that executes tag count aggregation, checking
        # the option is enabled and a document change modified tags.
        def should_update_#{tags_field}_aggregation?
          self.class.aggregate_#{tags_field}? &&          # check for blank? is needed to take account of new records
            previous_changes.include?('#{tags_field}') || previous_changes.blank?
        end
        
        def #{tags_field}=(s)
          super
          write_attribute(:#{tags_array_field}, convert_string_#{tags_field}_to_array(s))
        end
        
        def #{tags_array_field}=(a)
          super
          write_attribute(:#{tags_field}, convert_array_#{tags_field}_to_string(a))
        end
        
      END
      
    end
  end
end

