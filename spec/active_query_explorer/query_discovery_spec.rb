# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveQueryExplorer::QueryDiscovery do
  subject(:discovery) { described_class.new }

  let(:query_class) do
    klass = Class.new do
      def self.name
        "Billing::InvoiceQuery"
      end

      def self.queries
        [
          {
            name: :overdue,
            description: "Find overdue invoices",
            args_def: {
              days: { type: Integer, optional: false },
              status: { type: String, optional: true, default: "pending" }
            }
          },
          {
            name: :total_revenue,
            description: "Calculate total revenue"
          }
        ]
      end
    end
    klass
  end

  let(:query_class_no_namespace) do
    klass = Class.new do
      def self.name
        "SimpleQuery"
      end

      def self.queries
        [{ name: :all_records, description: "Return all records" }]
      end
    end
    klass
  end

  let(:query_class_nil_queries) do
    klass = Class.new do
      def self.name
        "EmptyQuery"
      end

      def self.queries
        nil
      end
    end
    klass
  end

  before do
    allow(ActiveQuery::Base).to receive(:registry).and_return(registry)
  end

  describe "#grouped_queries" do
    context "with multiple namespaced query classes" do
      let(:registry) { [query_class, query_class_no_namespace] }

      it "groups queries by namespace" do
        result = discovery.grouped_queries

        expect(result.length).to eq(2)

        billing_group = result.find { |g| g[:namespace] == "Billing" }
        root_group = result.find { |g| g[:namespace] == "" }

        expect(billing_group).not_to be_nil
        expect(root_group).not_to be_nil
      end

      it "includes class name in query object payload" do
        result = discovery.grouped_queries
        billing_group = result.find { |g| g[:namespace] == "Billing" }

        expect(billing_group[:query_objects].first[:class_name]).to eq("Billing::InvoiceQuery")
      end

      it "maps query metadata including parameters" do
        result = discovery.grouped_queries
        billing_group = result.find { |g| g[:namespace] == "Billing" }
        queries = billing_group[:query_objects].first[:queries]

        overdue = queries.find { |q| q[:name] == :overdue }

        expect(overdue[:description]).to eq("Find overdue invoices")
        expect(overdue[:params].length).to eq(2)

        days_param = overdue[:params].find { |p| p[:name] == :days }
        expect(days_param[:type]).to eq("Integer")
        expect(days_param[:optional]).to eq(false)

        status_param = overdue[:params].find { |p| p[:name] == :status }
        expect(status_param[:type]).to eq("String")
        expect(status_param[:optional]).to eq(true)
        expect(status_param[:default]).to eq("pending")
      end

      it "handles queries without parameters" do
        result = discovery.grouped_queries
        billing_group = result.find { |g| g[:namespace] == "Billing" }
        queries = billing_group[:query_objects].first[:queries]

        total = queries.find { |q| q[:name] == :total_revenue }
        expect(total[:params]).to eq([])
      end

      it "includes source location when available" do
        allow(Object).to receive(:const_source_location)
          .with("Billing::InvoiceQuery")
          .and_return(["/app/queries/billing/invoice_query.rb", 3])
        allow(Object).to receive(:const_source_location)
          .with("SimpleQuery")
          .and_return(nil)

        result = discovery.grouped_queries
        billing_group = result.find { |g| g[:namespace] == "Billing" }
        root_group = result.find { |g| g[:namespace] == "" }

        expect(billing_group[:query_objects].first[:source_location]).to eq(
          { file: "/app/queries/billing/invoice_query.rb", line: 3 }
        )
        expect(root_group[:query_objects].first[:source_location]).to be_nil
      end
    end

    context "with an empty registry" do
      let(:registry) { [] }

      it "returns an empty array" do
        expect(discovery.grouped_queries).to eq([])
      end
    end

    context "when registry contains non-class entries" do
      let(:registry) { [query_class, :not_a_class, "also not a class"] }

      it "filters out non-class entries" do
        result = discovery.grouped_queries
        expect(result.length).to eq(1)
        expect(result.first[:namespace]).to eq("Billing")
      end
    end

    context "when a query class returns nil for queries" do
      let(:registry) { [query_class_nil_queries] }

      it "handles nil queries gracefully" do
        result = discovery.grouped_queries
        expect(result.first[:query_objects].first[:queries]).to eq([])
      end
    end
  end

  describe "#find_query_class!" do
    let(:registry) { [query_class, query_class_no_namespace] }

    it "finds a query class by name" do
      result = discovery.find_query_class!("Billing::InvoiceQuery")
      expect(result).to eq(query_class)
    end

    it "raises NameError for unknown class" do
      expect {
        discovery.find_query_class!("Unknown::Query")
      }.to raise_error(NameError, "Unknown query class: Unknown::Query")
    end
  end

  describe "#find_query_def!" do
    let(:registry) { [query_class] }

    it "finds a query definition by name" do
      result = discovery.find_query_def!(query_class, :overdue)
      expect(result[:name]).to eq(:overdue)
      expect(result[:description]).to eq("Find overdue invoices")
    end

    it "raises NameError for unknown query" do
      expect {
        discovery.find_query_def!(query_class, :nonexistent)
      }.to raise_error(NameError, "Unknown query :nonexistent on Billing::InvoiceQuery")
    end

    it "handles classes with nil queries" do
      expect {
        discovery.find_query_def!(query_class_nil_queries, :anything)
      }.to raise_error(NameError, "Unknown query :anything on EmptyQuery")
    end
  end
end
