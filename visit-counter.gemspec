# -*- encoding: utf-8 -*-
require File.expand_path('../lib/visit-counter/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Tom Caspy"]
  gem.email         = ["tcaspy@gmail.com"]
  gem.description   = %q{Simple counter increment which only writes to DB once in a while}
  gem.summary       = %q{No need to write to db each visit, save the visits to a quick DB like redis or memcached, and write to the SQL db once reads exeeded a certain threshold}
  gem.homepage      = "https://github.com/KensoDev/visit-counter"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "visit-counter"
  gem.require_paths = ["lib"]
  gem.version       = VisitCounter::VERSION
  
  gem.add_development_dependency(%q<rspec>, [">= 0"])
  gem.add_development_dependency(%q<rake>, ["~> 0.9.2"])
  gem.add_dependency(%q<redis>, [">= 0"])
end
