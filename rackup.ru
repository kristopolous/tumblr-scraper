require 'api'
base = File.dirname(__FILE__)

#use Rack::ShowExceptions
#use Rack::ShowStatus

map "/megaup" do
  use Api
  run Rack::Server.new
end

map "/megadown" do
  use Api
  run Rack::Server.new
end

map "/down" do
  use Api
  run Rack::Server.new
end

map "/hide" do
  use Api
  run Rack::Server.new
end

map "/up" do
  use Api
  run Rack::Server.new
end

map "/relevant" do
  use Api
  run Rack::Server.new
end

map "/random" do
  use Api
  run Rack::Server.new
end

map "/" do |env|
  run Rack::File.new(base + "/static")
end

