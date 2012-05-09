# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ameblogazo/version"

Gem::Specification.new do |s|
  s.name        = "ameblogazo"
  s.version     = Ameblogazo::VERSION
  s.authors     = ["utahta"]
  s.email       = ["labs.ninxit@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{get ameba blog images}
  s.description = %q{get ameba blog images}

  s.rubyforge_project = "ameblogazo"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
  s.add_dependency('nokogiri')
end
