# frozen_string_literal: true

require "active_query"
require_relative "active_query_explorer/version"
require_relative "active_query_explorer/query_discovery"
require_relative "active_query_explorer/query_executor"
require_relative "active_query_explorer/result_serializer"
require_relative "active_query_explorer/query_text_formatter"
require_relative "active_query_explorer/engine" if defined?(Rails::Engine)

module ActiveQueryExplorer
  mattr_accessor :result_limit, default: 100
  mattr_accessor :query_paths, default: %w[queries query_objects]
  mattr_accessor :discovery_class, default: QueryDiscovery
  mattr_accessor :executor_class, default: QueryExecutor
  mattr_accessor :serializer_class, default: ResultSerializer
end
