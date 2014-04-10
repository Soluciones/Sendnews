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

  # s.add_dependency "rails", "~> 3.1.12"

  s.add_dependency "actionmailer", "~> 3.1.12"
  s.add_dependency "actionpack", "~> 3.1.12"
  # s.add_dependency "activerecord", "~> 3.1.12"
  s.add_dependency "activeresource", "~> 3.1.12"
  s.add_dependency "activesupport", "~> 3.1.12"
  s.add_dependency "railties", "~> 3.1.12"
  s.add_dependency "tzinfo"

  s.add_dependency "gatling_gun"
  # s.add_dependency "jquery-rails"

  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "ffaker"
  s.add_development_dependency "factory_girl_rails"
end
