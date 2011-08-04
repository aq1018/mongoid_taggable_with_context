require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  gem.name = "mongoid_taggable_with_context"
  gem.homepage = "http://github.com/aq1018/mongoid_taggable_with_context"
  gem.license = "MIT"
  gem.summary = %Q{Mongoid taggable behaviour}
  gem.description = %Q{It provides some helpers to create taggable documents with context.}
  gem.email = "aq1018@gmail.com"
  gem.authors = ["Aaron Qian"]
  gem.add_runtime_dependency 'mongoid', '>= 2'
  
  gem.add_development_dependency 'database_cleaner'
  gem.add_development_dependency 'bson', '~> 1.2.1'
  gem.add_development_dependency 'bson_ext', '~> 1.2.1'
  gem.add_development_dependency 'rspec', '~> 2.3.0'
  gem.add_development_dependency 'yard', '~> 0.6.0'
  gem.add_development_dependency 'bundler', '~> 1.0.0'
  gem.add_development_dependency 'jeweler', '~> 1.5.2'
  gem.add_development_dependency 'rcov', '>= 0'
  gem.add_development_dependency 'reek', '~> 1.2.8'
  gem.add_development_dependency 'roodi', '~> 2.1.0'
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
  spec.rspec_opts = "--color --format progress"
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
  spec.rcov_opts = "--exclude ~\/.rvm,spec"
end

require 'reek/rake/task'
Reek::Rake::Task.new do |t|
  t.fail_on_error = true
  t.verbose = false
  t.source_files = 'lib/**/*.rb'
end

require 'roodi'
require 'roodi_task'
RoodiTask.new do |t|
  t.verbose = false
end

task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new