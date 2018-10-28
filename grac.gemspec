lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'grac/version'

Gem::Specification.new do |spec|
  # For explanations see http://docs.rubygems.org/read/chapter/20
  spec.name          = "grac"
  spec.version       = Grac::VERSION
  spec.authors       = ["Tobias Schoknecht"]
  spec.email         = ["tobias.schoknecht@barzahlen.de"]
  spec.description   = %q{Generic REST API Client}
  spec.summary       = %q{Very generic client for REST API with basic error handling}
  spec.homepage      = "https://github.com/Barzahlen/grac"
  spec.license       = "MIT"

  spec.files         = Dir['lib/**/*.rb']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake",          "~> 12.3"
  spec.add_development_dependency "rspec",         "~> 3.8"
  spec.add_development_dependency "builder",       "~> 3.2"
  spec.add_development_dependency "benchmark-ips", "~> 2.7"
  spec.add_development_dependency "rack-test",     "~> 0.7"

  spec.add_runtime_dependency "oj", "~> 3.6.13"

  spec.add_dependency "typhoeus", "~> 0.6.9"
end
