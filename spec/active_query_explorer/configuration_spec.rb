# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveQueryExplorer do
  describe "configuration" do
    it "has a default result_limit of 100" do
      expect(described_class.result_limit).to eq(100)
    end

    it "has default query_paths" do
      expect(described_class.query_paths).to eq(%w[queries query_objects])
    end

    it "has default discovery_class" do
      expect(described_class.discovery_class).to eq(ActiveQueryExplorer::QueryDiscovery)
    end

    it "has default executor_class" do
      expect(described_class.executor_class).to eq(ActiveQueryExplorer::QueryExecutor)
    end

    it "has default serializer_class" do
      expect(described_class.serializer_class).to eq(ActiveQueryExplorer::ResultSerializer)
    end

    it "allows overriding result_limit" do
      original = described_class.result_limit
      described_class.result_limit = 50
      expect(described_class.result_limit).to eq(50)
    ensure
      described_class.result_limit = original
    end

    it "allows swapping discovery_class" do
      original = described_class.discovery_class
      custom = Class.new
      described_class.discovery_class = custom
      expect(described_class.discovery_class).to eq(custom)
    ensure
      described_class.discovery_class = original
    end

    it "allows swapping executor_class" do
      original = described_class.executor_class
      custom = Class.new
      described_class.executor_class = custom
      expect(described_class.executor_class).to eq(custom)
    ensure
      described_class.executor_class = original
    end

    it "allows swapping serializer_class" do
      original = described_class.serializer_class
      custom = Class.new
      described_class.serializer_class = custom
      expect(described_class.serializer_class).to eq(custom)
    ensure
      described_class.serializer_class = original
    end
  end
end
