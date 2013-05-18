mongoid_taggable_with_context
=============================

[![Build Status](https://secure.travis-ci.org/lgs/mongoid_taggable_with_context.png?branch=master)](http://travis-ci.org/lgs/mongoid_taggable_with_context) [![Dependency Status](https://gemnasium.com/lgs/mongoid_taggable_with_context.png?travis)](https://gemnasium.com/lgs/mongoid_taggable_with_context)

A tagging lib for Mongoid that allows for custom tagging along dynamic contexts. This gem was originally based on [mongoid_taggable](https://github.com/ches/mongoid_taggable) by Wilker Lúcio and Ches Martin. It has evolved substantially since that point, but all credit goes to them for the initial tagging functionality.

For instance, in a social network, a user might have tags that are called skills, interests, sports, and more. There is no real way to differentiate between tags and so an implementation of this type is not possible with `mongoid_taggable`.

Another example, aggregation such as counting tag occurrences was achieved by map-reduce with `mongoid_taggable`. It was ok for small amount of tags, but when the amount of tags and documents grow, the original `mongoid_taggable` won't be able to scale to real-time statistics demand.

Enter `mongoid_taggable_with_context`. Rather than tying functionality to a specific keyword (namely "tags"), `mongoid_taggable_with_context` allows you to specify an arbitrary number of *tag contexts* that can be used locally or in combination in the same way `mongoid_taggable` was used.

`mongoid_taggable_with_context` also provides flexibility on aggregation strategy. In addition to the map-reduce strategy, this gem also comes with real-time strategy. By using real-time strategy, your document can quickly adjusts the aggregation collection whenever tags are inserted or removed with $inc operator. So performance won't be impacted as the number of tags and documents grow.

Installation
------------

You can simply install from rubygems:

```
gem install mongoid_taggable_with_context
```

or in Gemfile:

```ruby
gem 'mongoid_taggable_with_context'
```


The "taggable" Macro Function
-----------------------------

Use the `taggable` macro function in your model to
declare a tags field. Specify `field name`
for tags, and `options` for tagging behavior.

Example:

   ```ruby
   class Article
     include Mongoid::Document
     include Mongoid::TaggableWithContext
     taggable :keywords, separator: ' ', default: ['foobar']
   end
   ```

* `@param [ Symbol ] field`

   (Optional) The name of the field for tags. Defaults to "tags"


* `@param [ Hash ] options`

   (Optional) Options for taggable behavior.


    * `@option [ String ] :separator`

        The delimiter used when converting the tags to and from String format. Defaults to " "


    * `@option [ <various> ] :default, :as, :localize, etc.`

        Options for Mongoid #field method will be automatically passed
        to the underlying Array field (with the exception of `:type`,
        which is coerced to `Array`).


Example Usage
-------------

To make a document taggable you need to include Mongoid::TaggableOnContext
into your document and call the *taggable* macro with optional arguments:

```ruby
class Post
  include Mongoid::Document
  include Mongoid::TaggableWithContext

  field :title
  field :content

  # default context is 'tags'.
  # This creates #tags, #tags=, #tags_string instance methods
  # separator is " " by default
  # #tags method returns an array of tags
  # #tags= methods accepts an array of tags or a separated string
  # #tags_string method returns a separated string
  taggable

  # tagging for 'skills' context.
  # This creates #skills, #skills=, #skills_string instance methods
  # changing tag separator to "," (Default is " ")
  taggable :skills, separator: ','

  # aliased context tagging.
  # This creates #interests, #interests=, #interests_string instance methods
  # The tags will be stored in a database field called 'ints'
  taggable :ints, as: :interests
end
```

Then in your form, for example:

```rhtml
<% form_for @post do |f| %>
  <p>
    <%= f.label :title %><br />
    <%= f.text_field :title %>
  </p>
  <p>
    <%= f.label :content %><br />
    <%= f.text_area :content %>
  </p>
  <p>
    <%= f.label :tags %><br />
    <%= text_field_tag 'post[tags]' %>
  </p>
  <p>
    <%= f.label :interests %><br />
    <%= text_field_tag 'post[interests]' %>
  </p>
  <p>
    <%= f.label :skills %><br />
    <%= text_field_tag 'post[skills]' %>
  </p>
  <p>
    <button type="submit">Send</button>
  </p>
<% end %>
```


Aggregation Strategies
----------------------

By including an aggregation strategy in your document, tag aggregations will be automatically available to you.
This lib presents the following aggregation strategies:

* MapReduce
* RealTime

The following document will automatically aggregate counts on all tag contexts.

```ruby
class Post
  include Mongoid::Document
  include Mongoid::TaggableWithContext

  # automatically adds real time aggregations to all tag contexts
  include Mongoid::TaggableWithContext::AggregationStrategy::RealTime

  # alternatively for map-reduce
  # include Mongoid::TaggableWithContext::AggregationStrategy::MapReduce

  field :title
  field :content

  taggable
  taggable :skills, separator: ','
  taggable :ints, as: interests
end
```

When you include an aggregation strategy, your document also gains a few extra methods to retrieve aggregation data.
In the case of previous example the following methods are included:

```ruby
Post.tags
Post.tags_with_weight
Post.interests
Post.interests_with_weight
Post.skills
Post.skills_with_weight
```

Here is how to use these methods in more detail:

```ruby
Post.create!(tags: "food,ant,bee")
Post.create!(tags: "juice,food,bee,zip")
Post.create!(tags: "honey,strip,food")

Post.tags # will retrieve ["ant", "bee", "food", "honey", "juice", "strip", "zip"]
Post.tags_with_weight # will retrieve:
# [
#   ['ant', 1],
#   ['bee', 2],
#   ['food', 3],
#   ['honey', 1],
#   ['juice', 1],
#   ['strip', 1],
#   ['zip', 1]
# ]
```


Contributing to mongoid_taggable_with_context
-----------------------------------------------

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.


Copyright
---------

Copyright (c) 2011 Aaron Qian. See LICENSE.txt for
further details.
