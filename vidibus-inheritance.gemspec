# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{vidibus-inheritance}
  s.version = "0.3.15"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Andre Pankratz"]
  s.date = %q{2010-10-22}
  s.description = %q{This gem allows inheritance of objects for Rails 3 with Mongoid. It will update all attributes and embedded documents of inheritors when ancestor gets changed.}
  s.email = %q{andre@vidibus.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".bundle/config",
     ".document",
     ".gitignore",
     ".rspec",
     "Gemfile",
     "Gemfile.lock",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "lib/vidibus-inheritance.rb",
     "lib/vidibus/inheritance.rb",
     "lib/vidibus/inheritance/mongoid.rb",
     "lib/vidibus/inheritance/validators.rb",
     "lib/vidibus/inheritance/validators/ancestor_validator.rb",
     "spec/models.rb",
     "spec/spec_helper.rb",
     "spec/vidibus/inheritance/cloning_spec.rb",
     "spec/vidibus/inheritance/inheritance_spec.rb",
     "spec/vidibus/inheritance/mongoid_spec.rb",
     "spec/vidibus/inheritance/validators/ancestor_validator_spec.rb",
     "vidibus-inheritance.gemspec"
  ]
  s.homepage = %q{http://github.com/vidibus/vidibus-inheritance}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Provides inheritance for models.}
  s.test_files = [
    "spec/models.rb",
     "spec/spec_helper.rb",
     "spec/vidibus/inheritance/cloning_spec.rb",
     "spec/vidibus/inheritance/inheritance_spec.rb",
     "spec/vidibus/inheritance/mongoid_spec.rb",
     "spec/vidibus/inheritance/validators/ancestor_validator_spec.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<mongoid>, ["~> 2.0.0.beta.20"])
      s.add_runtime_dependency(%q<vidibus-core_extensions>, [">= 0"])
      s.add_runtime_dependency(%q<vidibus-uuid>, [">= 0"])
    else
      s.add_dependency(%q<mongoid>, ["~> 2.0.0.beta.20"])
      s.add_dependency(%q<vidibus-core_extensions>, [">= 0"])
      s.add_dependency(%q<vidibus-uuid>, [">= 0"])
    end
  else
    s.add_dependency(%q<mongoid>, ["~> 2.0.0.beta.20"])
    s.add_dependency(%q<vidibus-core_extensions>, [">= 0"])
    s.add_dependency(%q<vidibus-uuid>, [">= 0"])
  end
end

