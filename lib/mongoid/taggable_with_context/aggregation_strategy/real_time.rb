module Mongoid::TaggableWithContext::AggregationStrategy
  module RealTime
    extend ActiveSupport::Concern
    
    included do
      set_callback :save,     :after, :update_tags_aggregation, :if => :tags_changed?
      set_callback :destroy,  :after, :update_tags_aggregation
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

    def changed_tag_arrays
      tag_array_attributes & changes.keys.map(&:to_sym)
    end
    
    def tags_changed?
      !changed_tag_arrays.empty?
    end
    
    def update_tags_aggregation
      changed_tag_arrays.each do |field_name|
        context = context_array_to_context_hash[field_name]
        coll = self.class.db.collection(self.class.aggregation_collection_for(context))
        field_name = self.class.tag_options_for(context)[:array_field]      
        old_tags, new_tags = changes["#{field_name}"]
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
    end
  end
end