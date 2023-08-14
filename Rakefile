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

task :check_lib_permissions do
  Dir["bin/*"].each do |filename|
    if !File.world_readable?(filename)
      raise 'All bin/* files must be world readable'
    end
  end
  Dir["lib/*.rb"].each do |filename|
    if !File.world_readable?(filename)
      raise 'All lib/*.rb files must be world readable'
    end
  end
end

Rake::Task[:build].enhance [:check_lib_permissions]
