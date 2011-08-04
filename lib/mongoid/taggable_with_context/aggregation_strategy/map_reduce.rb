module Mongoid::TaggableWithContext::AggregationStrategy
  module MapReduce
    extend ActiveSupport::Concern
    included do
      set_callback :create, :after, :update_tags_agregation_on_create
      set_callback :save, :after, :update_tags_aggregation_on_update
      set_callback :destroy, :after, :update_tags_aggregation_on_destroy
      delegate :aggregation_collection_for, :to => "self.class"
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
        db.collection(aggregation_collection_for(context)).find({:value => {"$gt" => 0 }}, conditions).to_a.map{ |t| [t["_id"], t["value"].to_i] }
      end
    end
    
    protected
    
    def trigger_update_tags_aggregation_on_create?
      changes.empty?
    end
    
    def trigger_update_tags_aggregation_on_update?
      !changed_contexts.empty?
    end
    
    def trigger_update_tags_aggregation_on_destroy?
      true
    end
    
    def update_tags_agregation_on_create
      return unless trigger_update_tags_aggregation_on_create?

      tag_contexts.each do |context|
        map_reduce_context_tags!(context)
      end
    end

    def update_tags_aggregation_on_update
      return unless trigger_update_tags_aggregation_on_update?

      changed_contexts.each do |context|
        map_reduce_context_tags!(context)
      end
    end

    def update_tags_aggregation_on_destroy
      return unless trigger_update_tags_aggregation_on_destroy?

      tag_contexts.each do |context|
        map_reduce_context_tags!(context)
      end
    end
    
    private
    
    def changed_contexts
      tag_contexts & changes.keys.map(&:to_sym)
    end
    
    def map_reduce_context_tags!(context)
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

      collection.master.map_reduce(map, reduce, :out => aggregation_collection_for(context))
    end
  end
end