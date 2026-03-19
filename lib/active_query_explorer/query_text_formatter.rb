# frozen_string_literal: true

module ActiveQueryExplorer
  class QueryTextFormatter
    def format(grouped_queries)
      grouped_queries.flat_map { |group| format_group(group) }.join("\n")
    end

    private

    def format_group(group)
      group[:query_objects].map { |qo| format_query_object(qo, group[:namespace]) }
    end

    def format_query_object(query_object, namespace)
      query_object[:queries].map do |query|
        format_query(query, query_object, namespace)
      end.join("\n")
    end

    def format_query(query, query_object, namespace)
      lines = []
      lines << "=== QUERY START ==="
      lines << "name: #{query_object[:class_name]}##{query[:name]}"
      lines << "namespace: #{namespace.presence || "root"}"
      lines << "description: #{query[:description] || "unknown"}"
      lines << "returns: unknown"
      lines << "side_effects: unknown"
      lines << "idempotent: unknown"
      lines << "safety: unknown"
      lines << ""
      lines << format_inputs(query[:params])
      lines << "=== QUERY END ==="
      lines.join("\n")
    end

    def format_inputs(params)
      return "inputs: none" if params.nil? || params.empty?

      lines = ["inputs:"]
      params.each do |param|
        lines << "- name: #{param[:name]}"
        lines << "  type: #{param[:type] || "unknown"}"
        lines << "  required: #{!param[:optional]}"
        lines << "  default: #{param.key?(:default) ? param[:default].inspect : "none"}"
      end
      lines.join("\n")
    end
  end
end
