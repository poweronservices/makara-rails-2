Rails::Initializer.run do |config|
  require 'makara'
  config.middleware.use Makara::Middleware
end
