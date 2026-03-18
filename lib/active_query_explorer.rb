# frozen_string_literal: true

require "active_query"
require_relative "active_query_explorer/version"
require_relative "active_query_explorer/engine" if defined?(Rails::Engine)

module ActiveQueryExplorer
  mattr_accessor :result_limit, default: 100
end
