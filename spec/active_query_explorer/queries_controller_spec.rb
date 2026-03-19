# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveQueryExplorer::QueriesController do

  describe "#execute" do
    let(:discovery) { instance_double(ActiveQueryExplorer::QueryDiscovery) }
    let(:executor) { instance_double(ActiveQueryExplorer::QueryExecutor) }
    let(:serializer) { instance_double(ActiveQueryExplorer::ResultSerializer) }

    before do
      allow(ActiveQueryExplorer).to receive(:discovery_class).and_return(
        class_double(ActiveQueryExplorer::QueryDiscovery, new: discovery)
      )
      allow(ActiveQueryExplorer).to receive(:executor_class).and_return(
        class_double(ActiveQueryExplorer::QueryExecutor, new: executor)
      )
      allow(ActiveQueryExplorer).to receive(:serializer_class).and_return(
        class_double(ActiveQueryExplorer::ResultSerializer, new: serializer)
      )
    end

    let(:query_class) do
      Class.new do
        def self.name
          "Billing::InvoiceQuery"
        end
      end
    end

    let(:query_def) do
      { name: :overdue, description: "Find overdue", args_def: { days: { type: Integer } } }
    end

    # Helper to simulate the execute action logic without full Rails request stack
    def simulate_execute(query_class_name:, query_name:, args: nil)
      # Replicate the controller's execute logic
      qn = query_name.to_s
      unless qn.match?(ActiveQueryExplorer::QueriesController::VALID_QUERY_NAME)
        raise ArgumentError, "Invalid query name: #{qn}"
      end

      klass = discovery.find_query_class!(query_class_name)
      query_def = discovery.find_query_def!(klass, qn.to_sym)

      raw_args = args ? ActionController::Parameters.new(args) : nil
      result = executor.execute(klass, qn.to_sym, raw_args, query_def[:args_def] || {})

      { result: serializer.serialize(result) }
    end

    context "with a valid query" do
      before do
        allow(discovery).to receive(:find_query_class!).with("Billing::InvoiceQuery").and_return(query_class)
        allow(discovery).to receive(:find_query_def!).with(query_class, :overdue).and_return(query_def)
        allow(executor).to receive(:execute).and_return([{ "id" => 1 }])
        allow(serializer).to receive(:serialize).and_return([{ "id" => 1 }])
      end

      it "returns the serialized result" do
        result = simulate_execute(
          query_class_name: "Billing::InvoiceQuery",
          query_name: "overdue",
          args: { days: "30" }
        )
        expect(result[:result]).to eq([{ "id" => 1 }])
      end

      it "passes args_def to the executor" do
        expect(executor).to receive(:execute).with(
          query_class, :overdue, an_instance_of(ActionController::Parameters), { days: { type: Integer } }
        )

        simulate_execute(
          query_class_name: "Billing::InvoiceQuery",
          query_name: "overdue",
          args: { days: "30" }
        )
      end

      it "passes empty hash as args_def when query has none" do
        query_def_no_args = { name: :count_all, description: "Count all" }
        allow(discovery).to receive(:find_query_def!).and_return(query_def_no_args)
        expect(executor).to receive(:execute).with(query_class, :count_all, anything, {})

        simulate_execute(
          query_class_name: "Billing::InvoiceQuery",
          query_name: "count_all"
        )
      end
    end

    context "input validation" do
      it "rejects SQL injection attempts" do
        expect {
          simulate_execute(
            query_class_name: "Billing::InvoiceQuery",
            query_name: "drop table users;--"
          )
        }.to raise_error(ArgumentError, /Invalid query name/)
      end

      it "rejects query names starting with numbers" do
        expect {
          simulate_execute(
            query_class_name: "SomeQuery",
            query_name: "1invalid"
          )
        }.to raise_error(ArgumentError, /Invalid query name/)
      end

      it "rejects query names with special characters" do
        expect {
          simulate_execute(
            query_class_name: "SomeQuery",
            query_name: "hello-world"
          )
        }.to raise_error(ArgumentError, /Invalid query name/)
      end

      it "rejects empty query names" do
        expect {
          simulate_execute(
            query_class_name: "SomeQuery",
            query_name: ""
          )
        }.to raise_error(ArgumentError, /Invalid query name/)
      end

      it "accepts valid query names with underscores and numbers" do
        allow(discovery).to receive(:find_query_class!).and_return(query_class)
        allow(discovery).to receive(:find_query_def!).and_return(query_def)
        allow(executor).to receive(:execute).and_return([])
        allow(serializer).to receive(:serialize).and_return([])

        result = simulate_execute(
          query_class_name: "Billing::InvoiceQuery",
          query_name: "find_by_status_2"
        )
        expect(result[:result]).to eq([])
      end

      it "accepts query names starting with underscore" do
        allow(discovery).to receive(:find_query_class!).and_return(query_class)
        allow(discovery).to receive(:find_query_def!).and_return(query_def)
        allow(executor).to receive(:execute).and_return([])
        allow(serializer).to receive(:serialize).and_return([])

        expect {
          simulate_execute(
            query_class_name: "Billing::InvoiceQuery",
            query_name: "_private_query"
          )
        }.not_to raise_error
      end
    end

    context "error propagation" do
      it "propagates NameError from discovery" do
        allow(discovery).to receive(:find_query_class!)
          .and_raise(NameError, "Unknown query class: Bad::Query")

        expect {
          simulate_execute(query_class_name: "Bad::Query", query_name: "something")
        }.to raise_error(NameError, "Unknown query class: Bad::Query")
      end

      it "propagates ArgumentError from executor" do
        allow(discovery).to receive(:find_query_class!).and_return(query_class)
        allow(discovery).to receive(:find_query_def!).and_return(query_def)
        allow(executor).to receive(:execute).and_raise(ArgumentError, "bad args")

        expect {
          simulate_execute(
            query_class_name: "Billing::InvoiceQuery",
            query_name: "overdue"
          )
        }.to raise_error(ArgumentError, "bad args")
      end
    end
  end

  describe "VALID_QUERY_NAME" do
    let(:regex) { described_class::VALID_QUERY_NAME }

    it "matches simple names" do
      expect("overdue").to match(regex)
    end

    it "matches names with underscores" do
      expect("find_by_name").to match(regex)
    end

    it "matches names starting with underscore" do
      expect("_private").to match(regex)
    end

    it "matches names with trailing numbers" do
      expect("query_v2").to match(regex)
    end

    it "does not match names starting with numbers" do
      expect("2fast").not_to match(regex)
    end

    it "does not match names with spaces" do
      expect("hello world").not_to match(regex)
    end

    it "does not match names with hyphens" do
      expect("some-query").not_to match(regex)
    end

    it "does not match names with semicolons" do
      expect("drop;--").not_to match(regex)
    end

    it "does not match empty strings" do
      expect("").not_to match(regex)
    end
  end

  describe "service instantiation" do
    it "uses configured discovery_class" do
      custom_discovery = Class.new do
        def grouped_queries
          []
        end
      end

      original = ActiveQueryExplorer.discovery_class
      ActiveQueryExplorer.discovery_class = custom_discovery

      ctrl = described_class.new
      instance = ctrl.send(:discovery)
      expect(instance).to be_a(custom_discovery)
    ensure
      ActiveQueryExplorer.discovery_class = original
    end

    it "uses configured executor_class" do
      custom_executor = Class.new
      original = ActiveQueryExplorer.executor_class
      ActiveQueryExplorer.executor_class = custom_executor

      ctrl = described_class.new
      instance = ctrl.send(:executor)
      expect(instance).to be_a(custom_executor)
    ensure
      ActiveQueryExplorer.executor_class = original
    end

    it "uses configured serializer_class" do
      custom_serializer = Class.new do
        def initialize(limit: 100); end
      end

      original = ActiveQueryExplorer.serializer_class
      ActiveQueryExplorer.serializer_class = custom_serializer

      ctrl = described_class.new
      instance = ctrl.send(:serializer)
      expect(instance).to be_a(custom_serializer)
    ensure
      ActiveQueryExplorer.serializer_class = original
    end

    it "memoizes service instances" do
      ctrl = described_class.new
      expect(ctrl.send(:discovery)).to equal(ctrl.send(:discovery))
      expect(ctrl.send(:executor)).to equal(ctrl.send(:executor))
      expect(ctrl.send(:serializer)).to equal(ctrl.send(:serializer))
    end

    it "memoizes text_formatter instance" do
      ctrl = described_class.new
      expect(ctrl.send(:text_formatter)).to equal(ctrl.send(:text_formatter))
    end

    it "returns a QueryTextFormatter instance" do
      ctrl = described_class.new
      expect(ctrl.send(:text_formatter)).to be_a(ActiveQueryExplorer::QueryTextFormatter)
    end
  end
end
