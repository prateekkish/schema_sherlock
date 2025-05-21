require_relative "lib/annotate_plus/version"

Gem::Specification.new do |spec|
  spec.name = "annotate_plus"
  spec.version = AnnotatePlus::VERSION
  spec.authors = ["Prateek Choudhary"]
  spec.email = ["prateekkish@gmail.com"]

  spec.summary = "Intelligent Rails model analysis and annotation tool"
  spec.description = "Extends beyond traditional schema annotation to provide intelligent analysis and actionable suggestions for Rails model code quality, performance, and maintainability."
  spec.homepage = "https://github.com/prateekkish/annotate_plus"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/prateekkish/annotate_plus"
  spec.metadata["changelog_uri"] = "https://github.com/prateekkish/annotate_plus/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.executables = ["annotate_plus"]
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "rails", ">= 6.0"
  spec.add_dependency "thor", "~> 1.0"
  spec.add_dependency "activerecord", ">= 6.0"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.0"
end