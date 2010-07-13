$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require "rubygems"
require "active_support/core_ext"
require "spec"
require "mongoid"
require "vidibus-uuid"
require "vidibus-inheritance"
require "rr"

Mongoid.configure do |config|
  name = "vidibus-inheritance_test"
  host = "localhost"
  config.master = Mongo::Connection.new.db(name)
end

Spec::Runner.configure do |config|  
  config.mock_with RR::Adapters::Rspec
  config.before(:each) do
    Mongoid.master.collections.select { |c| c.name != "system.indexes" }.each(&:drop)  
  end
end