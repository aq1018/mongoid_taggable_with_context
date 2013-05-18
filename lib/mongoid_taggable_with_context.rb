require 'active_support/concern'

require File.join(File.dirname(__FILE__), 'mongoid/taggable_with_context')
require File.join(File.dirname(__FILE__), 'mongoid/taggable_with_context/aggregation_strategy/map_reduce')
require File.join(File.dirname(__FILE__), 'mongoid/taggable_with_context/aggregation_strategy/real_time')
require File.join(File.dirname(__FILE__), 'mongoid/taggable_with_context/group_by/taggable_with_context')
require File.join(File.dirname(__FILE__), 'mongoid/taggable_with_context/group_by/aggregation_strategy/real_time')
require File.join(File.dirname(__FILE__), 'mongoid/taggable_with_context/version')