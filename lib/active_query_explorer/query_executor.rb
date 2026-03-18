# frozen_string_literal: true

module ActiveQueryExplorer
  class QueryExecutor
    def execute(klass, query_name, raw_args, args_def)
      args = coerce_args(raw_args, args_def)

      if args.empty?
        klass.public_send(query_name)
      else
        klass.public_send(query_name, args)
      end
    end

    private

    def coerce_args(args_hash, args_def)
      return {} if args_hash.blank?

      args_hash.to_unsafe_h.symbolize_keys.each_with_object({}) do |(key, value), result|
        next if value.blank? && (args_def.dig(key, :optional) == true)

        type = args_def.dig(key, :type)
        result[key] = coerce_value(value, type)
      end
    end

    def coerce_value(value, type)
      case type&.name
      when "Integer" then Integer(value)
      when "Float" then Float(value)
      when "ActiveQuery::Base::Boolean" then ActiveModel::Type::Boolean.new.cast(value)
      else value.to_s
      end
    end
  end
end
