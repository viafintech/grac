lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'grac/version'

Gem::Specification.new do |spec|
  # For explanations see http://docs.rubygems.org/read/chapter/20
  spec.name          = 'grac'
  spec.version       = Grac::VERSION
  spec.authors       = ['Tobias Schoknecht']
  spec.email         = ['tobias.schoknecht@viafintech.com']
  spec.description   = %q{Generic REST API Client}
  spec.summary       = %q{Very generic client for REST API with basic error handling}
  spec.homepage      = 'https://github.com/Barzahlen/grac'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*.rb']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.6'

  spec.add_development_dependency 'rake',          '~> 13.0'
  spec.add_development_dependency 'rspec',         '~> 3.12'
  spec.add_development_dependency 'builder',       '~> 3.2'
  spec.add_development_dependency 'benchmark-ips', '~> 2.10'
  spec.add_development_dependency 'rack',          '~> 3.0.1'
  spec.add_development_dependency 'rack-test',     '~> 2.0.2'

  spec.add_runtime_dependency 'oj',                '~> 3.13.23'
  spec.add_runtime_dependency 'typhoeus',          '~> 1'
end
