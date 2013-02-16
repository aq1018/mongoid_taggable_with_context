module Mongoid::TaggableWithContext::GroupBy
  module TaggableWithContext
    extend ActiveSupport::Concern
    include Mongoid::TaggableWithContext

    module ClassMethods
      def taggable(*args)
        super(*args)
        args.extract_options!
        tags_field = (args.blank? ? :tags : args.shift).to_sym
        self.taggable_with_context_options[tags_field].reverse_merge!(:group_by_field => nil)

        class_eval <<-END
          class << self
            def #{tags_field}(group_by=nil)
              tags_for(:"#{tags_field}", group_by)
            end

            def #{tags_field}_with_weight(group_by=nil)
              tags_with_weight_for(:"#{tags_field}", group_by)
            end

            def #{tags_field}_group_by_field
              get_tag_group_by_field_for(:"#{tags_field}")
            end
          end
        END
      end

      def tags_for(context, group_by, conditions={})
        raise AggregationStrategyMissing
      end

      def tags_with_weight_for(context, group_by, conditions={})
        raise AggregationStrategyMissing
      end

      def get_tag_group_by_field_for(context)
        self.taggable_with_context_options[context][:group_by_field]
      end
    end
  end
end