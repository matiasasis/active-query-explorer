# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActiveQueryExplorer::ResultSerializer do
  subject(:serializer) { described_class.new(limit: limit) }

  let(:limit) { 100 }

  describe "#serialize" do
    context "with ActiveRecord::Relation" do
      before do
        User.create!(name: "Alice", email: "alice@example.com", age: 30)
        User.create!(name: "Bob", email: "bob@example.com", age: 25)
        User.create!(name: "Carol", email: "carol@example.com", age: 35)
      end

      after { User.delete_all }

      it "returns records as JSON" do
        result = serializer.serialize(User.all)
        expect(result).to be_an(Array)
        expect(result.length).to eq(3)
        expect(result.first).to include("name" => "Alice")
      end

      it "respects the limit" do
        limited_serializer = described_class.new(limit: 2)
        result = limited_serializer.serialize(User.all)
        expect(result.length).to eq(2)
      end
    end

    context "with scalar values" do
      it "returns integers as-is" do
        expect(serializer.serialize(42)).to eq(42)
      end

      it "returns floats as-is" do
        expect(serializer.serialize(3.14)).to eq(3.14)
      end

      it "returns strings as-is" do
        expect(serializer.serialize("hello")).to eq("hello")
      end

      it "returns nil as-is" do
        expect(serializer.serialize(nil)).to be_nil
      end

      it "returns true as-is" do
        expect(serializer.serialize(true)).to eq(true)
      end

      it "returns false as-is" do
        expect(serializer.serialize(false)).to eq(false)
      end
    end

    context "with a single ActiveRecord::Base instance" do
      let!(:user) { User.create!(name: "Alice", email: "alice@example.com", age: 30) }

      after { User.delete_all }

      it "returns the record as JSON hash" do
        result = serializer.serialize(user)
        expect(result).to be_a(Hash)
        expect(result).to include("name" => "Alice", "email" => "alice@example.com")
      end
    end

    context "with Enumerable" do
      it "returns limited items as JSON" do
        items = (1..200).to_a
        limited_serializer = described_class.new(limit: 5)
        result = limited_serializer.serialize(items)
        expect(result).to eq([1, 2, 3, 4, 5])
      end

      it "returns array of hashes as JSON" do
        items = [{ a: 1 }, { b: 2 }]
        result = serializer.serialize(items)
        expect(result).to eq([{ "a" => 1 }, { "b" => 2 }])
      end
    end

    context "with other objects" do
      it "calls as_json on unknown types" do
        obj = double("custom_object", as_json: { "custom" => "data" })
        result = serializer.serialize(obj)
        expect(result).to eq({ "custom" => "data" })
      end
    end

    context "with default limit" do
      it "uses the configured result_limit" do
        original = ActiveQueryExplorer.result_limit
        ActiveQueryExplorer.result_limit = 50
        default_serializer = described_class.new
        expect(default_serializer.instance_variable_get(:@limit)).to eq(50)
      ensure
        ActiveQueryExplorer.result_limit = original
      end
    end
  end
end
