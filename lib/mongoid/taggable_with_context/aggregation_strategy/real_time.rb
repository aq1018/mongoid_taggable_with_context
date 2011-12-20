module Mongoid::TaggableWithContext::AggregationStrategy
  module RealTime
    extend ActiveSupport::Concern
    
    included do
      set_callback :save,     :after, :update_tags_aggregations_on_save
      set_callback :destroy,  :after, :update_tags_aggregations_on_destroy
    end
    
    module ClassMethods
      # Collection name for storing results of tag count aggregation
      def aggregation_collection_for(context)
        "#{collection_name}_#{context}_aggregation"
      end
      
      def tags_for(context, conditions={})
        conditions = {:sort => '_id'}.merge(conditions)
        db.collection(aggregation_collection_for(context)).find({:value => {"$gt" => 0 }}, conditions).to_a.map{ |t| t["_id"] }
      end

      # retrieve the list of tag with weight(count), this is useful for
      # creating tag clouds
      def tags_with_weight_for(context, conditions={})
        conditions = {:sort => '_id'}.merge(conditions)
        db.collection(aggregation_collection_for(context)).find({:value => {"$gt" => 0 }}, conditions).to_a.map{ |t| [t["_id"], t["value"]] }
      end
    end
    
    protected
    
    def update_tags_aggregation(context_array_field, old_tags=[], new_tags=[])
      context = context_array_to_context_hash[context_array_field]
      coll = self.class.db.collection(self.class.aggregation_collection_for(context))

      old_tags ||= []
      new_tags ||= []
      unchanged_tags  = old_tags & new_tags
      tags_removed    = old_tags - unchanged_tags
      tags_added      = new_tags - unchanged_tags
      
      tags_removed.each do |tag|
        coll.update({:_id => tag}, {'$inc' => {:value => -1}}, :upsert => true)
      end

      tags_added.each do |tag|
        coll.update({:_id => tag}, {'$inc' => {:value => 1}}, :upsert => true)
      end      
    end
    
    def update_tags_aggregations_on_save
      tag_array_attributes.each do |context_array|
        next if changes[context_array].nil?

        old_tags, new_tags = changes[context_array]
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