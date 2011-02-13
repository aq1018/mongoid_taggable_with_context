module Mongoid::TaggableWithContext::AggregationStrategy
  module RealTime
    extend ActiveSupport::Concern
    
    included do
      set_callback :create,   :after, :increment_tags_agregation
      set_callback :save,     :after, :update_tags_aggregation
      set_callback :destroy,  :after, :decrement_tags_aggregation
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
    
    private
    def need_update_tags_aggregation?
      !changed_contexts.empty?
    end

    def changed_contexts
      tag_contexts & previous_changes.keys.map(&:to_sym)
    end
    
    def increment_tags_agregation
      # if document is created by using MyDocument.new
      # and attributes are individually assigned
      # #previous_changes won't be empty and aggregation
      # is updated in after_save, so we simply skip it.
      return unless previous_changes.empty?

      # if the document is created by using MyDocument.create(:tags => "tag1 tag2")
      # #previous_changes hash is empty and we have to update aggregation here
      tag_contexts.each do |context|
        coll = self.class.db.collection(self.class.aggregation_collection_for(context))
        field_name = self.class.tag_options_for(context)[:array_field]
        tags = self.send field_name || []
        tags.each do |t|
          coll.update({:_id => t}, {'$inc' => {:value => 1}}, :upsert => true)
        end
      end
    end

    def decrement_tags_aggregation
      tag_contexts.each do |context|
        coll = self.class.db.collection(self.class.aggregation_collection_for(context))
        field_name = self.class.tag_options_for(context)[:array_field]
        tags = self.send field_name || []
        tags.each do |t|
          coll.update({:_id => t}, {'$inc' => {:value => -1}}, :upsert => true)
        end
      end
    end

    def update_tags_aggregation
      return unless need_update_tags_aggregation?

      changed_contexts.each do |context|
        coll = self.class.db.collection(self.class.aggregation_collection_for(context))
        field_name = self.class.tag_options_for(context)[:array_field]        
        old_tags, new_tags = previous_changes["#{field_name}"]
        old_tags ||= []
        new_tags ||= []
        unchanged_tags = old_tags & new_tags
        tags_removed = old_tags - unchanged_tags
        tags_added = new_tags - unchanged_tags

        tags_removed.each do |t|
          coll.update({:_id => t}, {'$inc' => {:value => -1}}, :upsert => true)
        end

        tags_added.each do |t|
          coll.update({:_id => t}, {'$inc' => {:value => 1}}, :upsert => true)
        end
      end
    end
  end
end