# frozen_string_literal: true

module ActiveQueryExplorer
  class ResultSerializer
    def serialize(result)
      case result
      when ActiveRecord::Relation then result.limit(100).as_json
      when Integer, Float, String, NilClass, TrueClass, FalseClass then result
      when ActiveRecord::Base then result.as_json
      when Enumerable then result.first(100).as_json
      else result.as_json
      end
    end
  end
end
