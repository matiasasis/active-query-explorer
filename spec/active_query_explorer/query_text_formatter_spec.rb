# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveQueryExplorer::QueryTextFormatter do
  subject(:formatter) { described_class.new }

  let(:grouped_queries) do
    [
      {
        namespace: "Billing",
        query_objects: [
          {
            class_name: "Billing::InvoiceQuery",
            source_location: { file: "/app/queries/billing/invoice_query.rb", line: 3 },
            queries: [
              {
                name: :overdue,
                description: "Find overdue invoices",
                params: [
                  { name: :days, type: "Integer", optional: false },
                  { name: :status, type: "String", optional: true, default: "pending" }
                ]
              },
              {
                name: :total_revenue,
                description: "Calculate total revenue",
                params: []
              }
            ]
          }
        ]
      },
      {
        namespace: "",
        query_objects: [
          {
            class_name: "SimpleQuery",
            source_location: nil,
            queries: [
              {
                name: :all_records,
                description: "Return all records",
                params: []
              }
            ]
          }
        ]
      }
    ]
  end

  describe "#format" do
    it "returns a string" do
      expect(formatter.format(grouped_queries)).to be_a(String)
    end

    it "wraps each query in start/end delimiters" do
      result = formatter.format(grouped_queries)

      expect(result.scan("=== QUERY START ===").count).to eq(3)
      expect(result.scan("=== QUERY END ===").count).to eq(3)
    end

    it "includes the fully qualified query name" do
      result = formatter.format(grouped_queries)

      expect(result).to include("name: Billing::InvoiceQuery#overdue")
      expect(result).to include("name: Billing::InvoiceQuery#total_revenue")
      expect(result).to include("name: SimpleQuery#all_records")
    end

    it "includes the namespace" do
      result = formatter.format(grouped_queries)

      expect(result).to include("namespace: Billing")
    end

    it "uses 'root' for empty namespace" do
      result = formatter.format(grouped_queries)

      expect(result).to include("namespace: root")
    end

    it "includes the description" do
      result = formatter.format(grouped_queries)

      expect(result).to include("description: Find overdue invoices")
      expect(result).to include("description: Calculate total revenue")
    end

    it "includes unknown fields for metadata not in the registry" do
      result = formatter.format(grouped_queries)

      expect(result).to include("returns: unknown")
      expect(result).to include("side_effects: unknown")
      expect(result).to include("idempotent: unknown")
      expect(result).to include("safety: unknown")
    end

    context "with parameters" do
      it "lists input names and types" do
        result = formatter.format(grouped_queries)

        expect(result).to include("- name: days")
        expect(result).to include("  type: Integer")
        expect(result).to include("- name: status")
        expect(result).to include("  type: String")
      end

      it "indicates required status" do
        result = formatter.format(grouped_queries)

        expect(result).to include("  required: true")
        expect(result).to include("  required: false")
      end

      it "includes default values" do
        result = formatter.format(grouped_queries)

        expect(result).to include('  default: "pending"')
      end

      it "shows 'none' for parameters without defaults" do
        result = formatter.format(grouped_queries)

        expect(result).to include("  default: none")
      end
    end

    context "without parameters" do
      it "renders 'inputs: none'" do
        single_query = [
          {
            namespace: "Test",
            query_objects: [
              {
                class_name: "Test::NoArgsQuery",
                source_location: nil,
                queries: [{ name: :run, description: "Run it", params: [] }]
              }
            ]
          }
        ]

        result = formatter.format(single_query)

        expect(result).to include("inputs: none")
      end
    end

    context "with nil params" do
      it "renders 'inputs: none'" do
        single_query = [
          {
            namespace: "Test",
            query_objects: [
              {
                class_name: "Test::NilParamsQuery",
                source_location: nil,
                queries: [{ name: :run, description: "Run it", params: nil }]
              }
            ]
          }
        ]

        result = formatter.format(single_query)

        expect(result).to include("inputs: none")
      end
    end

    context "with nil description" do
      it "renders 'unknown' for missing description" do
        single_query = [
          {
            namespace: "Test",
            query_objects: [
              {
                class_name: "Test::NoDescQuery",
                source_location: nil,
                queries: [{ name: :run, description: nil, params: [] }]
              }
            ]
          }
        ]

        result = formatter.format(single_query)

        expect(result).to include("description: unknown")
      end
    end

    context "with empty grouped_queries" do
      it "returns an empty string" do
        expect(formatter.format([])).to eq("")
      end
    end

    context "with param missing type" do
      it "renders 'unknown' for missing type" do
        single_query = [
          {
            namespace: "Test",
            query_objects: [
              {
                class_name: "Test::UntypedQuery",
                source_location: nil,
                queries: [
                  {
                    name: :run,
                    description: "Run it",
                    params: [{ name: :value, optional: false }]
                  }
                ]
              }
            ]
          }
        ]

        result = formatter.format(single_query)

        expect(result).to include("  type: unknown")
      end
    end
  end
end
