# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lockistics/version'

Gem::Specification.new do |spec|
  spec.name          = "lockistics"
  spec.version       = Lockistics::VERSION
  spec.authors       = ["Kimmo Lehto"]
  spec.email         = ["kimmo.lehto@gmail.com"]
  spec.description   = %q{Statsistics collecting shared mutex on Redis}
  spec.summary       = %q{With lockistics you can use Redis to create distributed locks and collect statistics how often and how long your locks are held}
  spec.homepage      = "https://github.com/kke/lockistics"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "redis"
  spec.add_runtime_dependency "os"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "fakeredis"
end
