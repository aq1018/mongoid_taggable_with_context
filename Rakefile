require 'rubygems'
require 'bundler'
Bundler.setup

require 'rake'
require 'jeweler'

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'mongoid/taggable_with_context/version'

Jeweler::Tasks.new do |gem|
  gem.name = "mongoid_taggable_with_context"
  gem.homepage = "http://github.com/lgs/mongoid_taggable_with_context"
  gem.license = "MIT"
  gem.summary = %Q{Mongoid taggable behaviour}
  gem.description = %Q{Add multiple tag fields on Mongoid documents with aggregation capability.}
  gem.authors = ["Aaron Qian", "Luca G. Soave", "John Shields", "Wilker Lucio", "Ches Martin"]
  gem.version = Mongoid::TaggableWithContext::VERSION
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
  spec.rspec_opts = "--color --format progress"
end

task default: :spec

require 'yard'
YARD::Rake::YardocTask.new
