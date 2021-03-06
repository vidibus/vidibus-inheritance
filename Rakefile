require "rubygems"
require "rake"
require "rake/rdoctask"
require "rspec"
require "rspec/core/rake_task"

begin
  require "jeweler"
  Jeweler::Tasks.new do |gem|
    gem.name = "vidibus-inheritance"
    gem.summary = %Q{Provides inheritance for models.}
    gem.description = %Q{This gem allows inheritance of objects for Rails 3 with Mongoid. It will update all attributes and embedded documents of inheritors when ancestor gets changed.}
    gem.email = "andre@vidibus.com"
    gem.homepage = "http://github.com/vidibus/vidibus-inheritance"
    gem.authors = ["Andre Pankratz"]
    gem.add_dependency "mongoid", "~> 2.0.0.beta.20"
    gem.add_dependency "vidibus-core_extensions"
    gem.add_dependency "vidibus-uuid"
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

Rspec::Core::RakeTask.new(:rcov) do |t|
  t.pattern = "spec/**/*_spec.rb"
  t.rcov = true
  t.rcov_opts = ["--exclude", "^spec,/gems/"]
end

Rake::RDocTask.new do |rdoc|
  version = File.exist?("VERSION") ? File.read("VERSION") : ""
  rdoc.rdoc_dir = "rdoc"
  rdoc.title = "vidibus-inheritance #{version}"
  rdoc.rdoc_files.include("README*")
  rdoc.rdoc_files.include("lib/**/*.rb")
  rdoc.options << "--charset=utf-8"
end
