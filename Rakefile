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
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "mongoid_taggable_with_type"
  gem.homepage = "http://github.com/aq1018/mongoid_taggable_with_type"
  gem.license = "MIT"
  gem.summary = %Q{Mongoid taggable behaviour}
  gem.description = %Q{It provides some helpers to create taggable documents with context.}
  gem.email = "aq1018@gmail.com"
  gem.authors = ["Aaron Qian"]
  gem.add_runtime_dependency 'mongoid', '~> 2.0.0.beta.20'
  #gem.add_development_dependency 'database_cleaner', '~> 0.6.0'
  #gem.add_development_dependency 'rake',  '~> 0.8.7'
  #gem.add_development_dependency 'rspec', '~> 2.1.0'
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

require 'rcov/rcovtask'
Rcov::RcovTask.new do |test|
  test.libs << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "mongoid_taggable_with_type #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
