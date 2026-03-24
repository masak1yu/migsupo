require_relative "lib/migsupo/version"

Gem::Specification.new do |spec|
  spec.name          = "migsupo"
  spec.version       = Migsupo::VERSION
  spec.authors       = ["masak1yu"]
  spec.summary       = "Generate Rails migrations from a Schemafile diff"
  spec.description   = "Like ridgepole but outputs Rails migration files instead of applying schema changes directly to the DB"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*", "*.gemspec", "README.md"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "activerecord", ">= 6.1"
  spec.add_dependency "activesupport", ">= 6.1"

  spec.add_development_dependency "railties", ">= 6.1"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "sqlite3", ">= 1.4"
end
