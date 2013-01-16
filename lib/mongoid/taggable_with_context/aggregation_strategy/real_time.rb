module Mongoid::TaggableWithContext::AggregationStrategy
  module RealTime
    extend ActiveSupport::Concern
    
    included do
      set_callback :save,     :after, :update_tags_aggregations_on_save
      set_callback :destroy,  :after, :update_tags_aggregations_on_destroy
    end
    
    module ClassMethods
      # Collection name for storing results of tag count aggregation

      def aggregation_database_collection_for(context)
        (@aggregation_database_collection ||= {})[context] ||= Moped::Collection.new(self.collection.database, aggregation_collection_for(context))
      end

      def aggregation_collection_for(context)
        "#{collection_name}_#{context}_aggregation"
      end
      
      def tags_for(context, conditions={})
        aggregation_database_collection_for(context).find({:value => {"$gt" => 0 }}).sort(_id: 1).to_a.map{ |t| t["_id"] }
      end

      # retrieve the list of tag with weight(count), this is useful for
      # creating tag clouds
      def tags_with_weight_for(context, conditions={})
        aggregation_database_collection_for(context).find({:value => {"$gt" => 0 }}).sort(_id: 1).to_a.map{ |t| [t["_id"], t["value"].to_i] }
      end

      def recalculate_all_context_tag_weights!
        tag_contexts.each do |context|
          recalculate_tag_weights!(context)
        end
      end

      def recalculate_tag_weights!(context)
        field = tag_options_for(context)[:array_field]

        map = <<-END
          function() {
            if (!this.#{field})return;
            for (index in this.#{field})
              emit(this.#{field}[index], 1);
          }
        END

        reduce = <<-END
          function(key, values) {
            var count = 0;
            for (index in values) count += values[index];
            return count;
          }
        END

        self.map_reduce(map, reduce).out(replace: aggregation_collection_for(context)).time
      end

      # adapted from https://github.com/jesuisbonbon/mongoid_taggable/commit/42feddd24dedd66b2b6776f9694d1b5b8bf6903d
      def tags_autocomplete(context, criteria, options={})
        result = aggregation_database_collection_for(context).find({:_id => /^#{criteria}/})
        result = result.sort(value: -1) if options[:sort_by_count] == true
        result = result.limit(options[:max]) if options[:max] > 0
        result.to_a.map{ |r| [r["_id"], r["value"]] }
      end
    end
    
    protected
    
    def update_tags_aggregation(context_array_field, old_tags=[], new_tags=[])
      context = context_array_to_context_hash[context_array_field]
      coll = self.class.aggregation_database_collection_for(context)

      old_tags ||= []
      new_tags ||= []
      unchanged_tags  = old_tags & new_tags
      tags_removed    = old_tags - unchanged_tags
      tags_added      = new_tags - unchanged_tags

      
      tags_removed.each do |tag|
        coll.find({_id: tag}).upsert({'$inc' => {:value => -1}})
      end
      tags_added.each do |tag|
        coll.find({_id: tag}).upsert({'$inc' => {:value => 1}})
      end
      #coll.find({_id: {"$in" => tags_removed}}).update({'$inc' => {:value => -1}}, [:upsert])
      #coll.find({_id: {"$in" => tags_added}}).update({'$inc' => {:value => 1}}, [:upsert])
    end
    
    def update_tags_aggregations_on_save
      indifferent_changes = HashWithIndifferentAccess.new changes
      tag_array_attributes.each do |context_array|
        next if indifferent_changes[context_array].nil?

        old_tags, new_tags = indifferent_changes[context_array]
        update_tags_aggregation(context_array, old_tags, new_tags)
      end
    end
    
    def update_tags_aggregations_on_destroy
      tag_array_attributes.each do |context_array|
        old_tags = send context_array
        new_tags = []
        update_tags_aggregation(context_array, old_tags, new_tags)
      end      
    end
  end
end
