# frozen_string_literal: true

module ActiveQueryExplorer
  class ResultSerializer
    def initialize(limit: ActiveQueryExplorer.result_limit)
      @limit = limit
    end

    def serialize(result)
      case result
      when ActiveRecord::Relation then result.limit(@limit).as_json
      when Integer, Float, String, NilClass, TrueClass, FalseClass then result
      when ActiveRecord::Base then result.as_json
      when Enumerable then result.first(@limit).as_json
      else result.as_json
      end
    end
  end
end
