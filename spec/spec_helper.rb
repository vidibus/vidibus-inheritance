$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require "rubygems"
require "active_support/core_ext"
require "spec"
require "rr"
require "mongoid"
require "vidibus-uuid"
require "vidibus-inheritance"
require "models"

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

# Helper for stubbing time. Define String to be set as Time.now.
# example: stub_time!('01.01.2010 14:00')
# example: stub_time!(2.days.ago)
def stub_time!(string = nil)
  now = string ? Time.parse(string.to_s) : Time.now
  stub(Time).now { now }
  now
end