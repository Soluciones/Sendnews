$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "sendnews/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "sendnews"
  s.version     = Sendnews::VERSION
  s.authors     = ["Rankia"]
  s.email       = ["rails@rankia.com"]
  s.homepage    = "https://github.com/Soluciones/Sendnews"
  s.summary     = "An engine to send newsletters"
  s.description = s.summary

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.1.5"

  s.add_development_dependency 'pg'

  s.add_dependency "gatling_gun"
  # s.add_dependency "jquery-rails"

  s.add_development_dependency 'rspec-rails', '~> 2.14.2'
  s.add_development_dependency "ffaker"
  s.add_development_dependency "factory_girl_rails"
end
