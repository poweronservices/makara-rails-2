require File.expand_path('../lib/makara/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Mike Nelson", "Joel Barker"]
  gem.email         = ["mike@mikeonrails.com", "joelbarker@poweron.com"]
  gem.description   = %q{Read-write splitting and failover for your DB in Rails 2 yo}
  gem.summary       = %q{Read-write splitting and failover for your DB in Rails 2 yo}
  gem.homepage      = "https://github.com/poweronservices/makara-rails-2"
  gem.licenses      = ['MIT']
  gem.metadata      = {
    "source_code_uri" => 'https://github.com/poweronservices/makara-rails-2'
  }

  gem.files         = Dir.glob('makara/**/*')
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "makara"
  gem.require_paths = ["lib"]
  gem.version       = Makara::VERSION

  gem.required_ruby_version = ">= 2.5.0"

  gem.add_dependency "activerecord", "~> 2.3"

  gem.add_development_dependency "rack"
  gem.add_development_dependency "rake", "~> 13.0"
  gem.add_development_dependency "rspec", "~> 3.9"
  gem.add_development_dependency "timecop"
  gem.add_development_dependency "rubocop"
  gem.add_development_dependency "rubocop-thread_safety"
  gem.add_development_dependency "brakeman"
  gem.add_development_dependency "rubycritic"
  gem.add_development_dependency "inch"

  gem.add_development_dependency "pry-byebug"
  gem.add_development_dependency "mysql2"
  gem.add_development_dependency "rgeo"
end
