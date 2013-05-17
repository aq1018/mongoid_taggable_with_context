module Mongoid::TaggableWithContext::GroupBy::AggregationStrategy
  module RealTime
    extend ActiveSupport::Concern
    include Mongoid::TaggableWithContext::GroupBy::TaggableWithContext
    include Mongoid::TaggableWithContext::AggregationStrategy::RealTime

    module ClassMethods
      def tag_name_attribute
        "_name"
      end

      def tags_for(context, group_by, conditions={})
        results = if group_by
          query(context, group_by).to_a.map{ |t| t[tag_name_attribute] }
        else
          super(context, conditions)
        end
        results.uniq
      end

      def tags_with_weight_for(context, group_by, conditions={})
        results = if group_by
          query(context, group_by).to_a.map{ |t| [t[tag_name_attribute], t["value"].to_i] }
        else
          super(context, conditions)
        end

        tag_hash = {}
        results.each do |tag, weight|
          tag_hash[tag] ||= 0
          tag_hash[tag] += weight
        end
        tag_hash.to_a
      end

      protected
      def query(context, group_by)
        aggregation_database_collection_for(context).find({value: {"$gt" => 0 }, group_by_field: group_by}).sort(tag_name_attribute.to_sym => 1)
      end
    end

    protected

    def get_conditions(context, tag)
      conditions = {self.class.tag_name_attribute.to_sym => tag}
      group_by_field = self.class.get_tag_group_by_field_for(context)
      if group_by_field
        conditions.merge!({group_by_field: self.send(group_by_field)})
      end
      conditions
    end
  end
end