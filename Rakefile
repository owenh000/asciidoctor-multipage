require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.libs << "lib"
end

task :default => :test

#if !ENV["APPRAISAL_INITIALIZED"] && !ENV["TRAVIS"]
#  task :default => :appraisal
#end
