# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveQueryExplorer::QueryExecutor do
  subject(:executor) { described_class.new }

  let(:query_class) do
    klass = Class.new do
      def self.name
        "TestQuery"
      end

      def self.find_by_status(args = {})
        "found: #{args[:status]}"
      end

      def self.count_all
        42
      end
    end
    klass
  end

  describe "#execute" do
    context "with no arguments" do
      it "calls the query method without arguments" do
        result = executor.execute(query_class, :count_all, nil, {})
        expect(result).to eq(42)
      end

      it "calls the query method when args are empty hash" do
        params = ActionController::Parameters.new({})
        result = executor.execute(query_class, :count_all, params, {})
        expect(result).to eq(42)
      end
    end

    context "with arguments" do
      let(:args_def) do
        {
          status: { type: String, optional: false }
        }
      end

      it "coerces and passes arguments to the query method" do
        raw_args = ActionController::Parameters.new({ "status" => "active" })
        result = executor.execute(query_class, :find_by_status, raw_args, args_def)
        expect(result).to eq("found: active")
      end
    end

    context "with optional arguments" do
      let(:args_def) do
        {
          status: { type: String, optional: true },
          limit: { type: Integer, optional: false }
        }
      end

      let(:query_class_with_optional) do
        Class.new do
          def self.name
            "OptionalArgsQuery"
          end

          def self.search(args = {})
            args
          end
        end
      end

      it "skips blank optional arguments" do
        raw_args = ActionController::Parameters.new({ "status" => "", "limit" => "10" })
        result = executor.execute(query_class_with_optional, :search, raw_args, args_def)
        expect(result).not_to have_key(:status)
        expect(result[:limit]).to eq(10) # coerced via TypeRegistry
      end
    end

    context "with type coercion" do
      let(:args_def) do
        { count: { type: Integer } }
      end

      let(:query_class_typed) do
        Class.new do
          def self.name
            "TypedQuery"
          end

          def self.with_count(args = {})
            args[:count]
          end
        end
      end

      it "coerces values using TypeRegistry when a coercer exists" do
        raw_args = ActionController::Parameters.new({ "count" => "5" })
        result = executor.execute(query_class_typed, :with_count, raw_args, args_def)
        expect(result).to eq(5)
        expect(result).to be_a(Integer)
      end
    end

    context "with unknown type" do
      let(:custom_type) { Class.new }
      let(:args_def) do
        { value: { type: custom_type } }
      end

      let(:query_class_custom) do
        Class.new do
          def self.name
            "CustomTypeQuery"
          end

          def self.process(args = {})
            args[:value]
          end
        end
      end

      it "falls back to to_s for types without a coercer" do
        raw_args = ActionController::Parameters.new({ "value" => "hello" })
        result = executor.execute(query_class_custom, :process, raw_args, args_def)
        expect(result).to eq("hello")
        expect(result).to be_a(String)
      end
    end

    context "with nil type" do
      let(:args_def) do
        { name: { type: nil } }
      end

      let(:query_class_nil_type) do
        Class.new do
          def self.name
            "NilTypeQuery"
          end

          def self.lookup(args = {})
            args[:name]
          end
        end
      end

      it "falls back to to_s when type is nil" do
        raw_args = ActionController::Parameters.new({ "name" => "test" })
        result = executor.execute(query_class_nil_type, :lookup, raw_args, args_def)
        expect(result).to eq("test")
      end
    end

    context "argument whitelisting" do
      let(:args_def) do
        { allowed: { type: String } }
      end

      let(:query_class_whitelist) do
        Class.new do
          def self.name
            "WhitelistQuery"
          end

          def self.safe_query(args = {})
            args
          end
        end
      end

      it "only permits keys defined in args_def" do
        raw_args = ActionController::Parameters.new({
          "allowed" => "yes",
          "injected" => "malicious"
        })
        result = executor.execute(query_class_whitelist, :safe_query, raw_args, args_def)
        expect(result).to have_key(:allowed)
        expect(result).not_to have_key(:injected)
      end
    end
  end
end
