# frozen_string_literal: true

require "bundler/setup"
require "active_record"
require "action_controller"
require "action_dispatch"
require "active_query"
require "rails"
require "active_query_explorer"
require_relative "../app/controllers/active_query_explorer/queries_controller"

# Minimal ActiveRecord setup for testing
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
    t.string :email
    t.integer :age
    t.timestamps null: false
  end
end

class User < ActiveRecord::Base; end

# Stub ActiveQuery::Base.registry since the gem doesn't provide it natively
unless ActiveQuery::Base.respond_to?(:registry)
  module ActiveQuery
    module Base
      def self.registry
        @registry ||= []
      end

      def self.clear_registry!
        @registry = []
      end
    end
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  Kernel.srand config.seed
end
