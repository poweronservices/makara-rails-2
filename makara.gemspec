require File.expand_path('lib/makara/version', __dir__)

Gem::Specification.new do |gem|
  gem.authors       = ['Mike Nelson', 'Joel Barker']
  gem.email         = ['mike@mikeonrails.com', 'joelbarker@poweron.com']
  gem.description   = 'Read-write splitting and failover for your DB in Rails 2 yo'
  gem.summary       = 'Read-write splitting and failover for your DB in Rails 2 yo'
  gem.homepage      = 'https://github.com/poweronservices/makara-rails-2'
  gem.licenses      = ['MIT']
  gem.metadata      = {
    'source_code_uri' => 'https://github.com/poweronservices/makara-rails-2',
    'rubygems_mfa_required' => 'true'
  }

  gem.files         = Dir.glob('makara/**/*')
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.name          = 'makara'
  gem.require_paths = ['lib']
  gem.version       = Makara::VERSION

  gem.required_ruby_version = '~> 3.0'

  gem.add_dependency 'activerecord', '~> 2.3'
  gem.add_dependency 'ruby3-backward-compatibility'
  gem.add_dependency 'activerecord-mysql2-adapter'

  gem.add_development_dependency 'brakeman'
  gem.add_development_dependency 'inch'
  gem.add_development_dependency 'rack'
  gem.add_development_dependency 'rake', '~> 13.0'
  gem.add_development_dependency 'rspec', '~> 3.9'
  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'rubocop'
  gem.add_development_dependency 'rubocop-thread_safety'
  gem.add_development_dependency 'rubycritic'
  gem.add_development_dependency 'timecop'
end
