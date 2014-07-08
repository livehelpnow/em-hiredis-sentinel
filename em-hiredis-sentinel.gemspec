# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'em-hiredis-sentinel/version'

Gem::Specification.new do |spec|
  spec.name          = "em-hiredis-sentinel"
  spec.version       = EventMachine::Hiredis::Sentinel::VERSION
  spec.authors       = ["Justin Schneck"]
  spec.email         = ["jschneck@mac.com"]
  spec.summary       = %q{Redis Sentinel for em-hiredis}
  spec.description   = %q{Monkey patches em-hiredis with sentinel support for failover}
  spec.homepage      = "https://github.com/mobileoverlord/em-hiredis-sentinel"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_dependency 'em-hiredis'
end