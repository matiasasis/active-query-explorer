# frozen_string_literal: true

require_relative "lib/active_query_explorer/version"

Gem::Specification.new do |spec|
  spec.name = "active-query-explorer"
  spec.version = ActiveQueryExplorer::VERSION
  spec.authors = ["Matias Asis"]
  spec.email = ["matiasis.90@gmail.com"]

  spec.summary = "A mountable Rails engine for browsing and executing ActiveQuery query objects."
  spec.description = "ActiveQuery Explorer provides a web GUI (similar to GraphiQL) that discovers all registered ActiveQuery objects, displays their metadata, and allows executing them with parameters."
  spec.homepage = "https://github.com/matiasasis/active-query-explorer"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/matiasasis/active-query-explorer"
  spec.metadata["bug_tracker_uri"] = "https://github.com/matiasasis/active-query-explorer/issues"
  spec.metadata["changelog_uri"] = "https://github.com/matiasasis/active-query-explorer/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile]) ||
        f.match?(/\.gem\z/)
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "active-query", ">= 0.1.3"
  spec.add_dependency "actionpack", ">= 6.1", "< 9.0"
  spec.add_dependency "railties", ">= 6.1", "< 9.0"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.9"
  spec.add_development_dependency "activerecord", ">= 6.1", "< 9.0"
  spec.add_development_dependency "sqlite3"
end
