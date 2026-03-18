# frozen_string_literal: true

module ActiveQueryExplorer
  class QueriesController < ActionController::Base
    layout false

    VALID_QUERY_NAME = /\A[a-zA-Z_]\w*\z/

    def index
      respond_to do |format|
        format.html
        format.json { render json: discovery.grouped_queries }
      end
    end

    def execute
      query_name = params[:query_name].to_s
      unless query_name.match?(VALID_QUERY_NAME)
        raise ArgumentError, "Invalid query name: #{query_name}"
      end

      klass = discovery.find_query_class!(params[:query_class])
      query_def = discovery.find_query_def!(klass, query_name.to_sym)

      result = executor.execute(klass, query_name.to_sym, params[:args], query_def[:args_def] || {})

      render json: { result: serializer.serialize(result) }
    rescue ArgumentError, NameError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error("ActiveQueryExplorer: #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
      render json: { error: "#{e.class}: #{e.message}" }, status: :internal_server_error
    end

    private

    def discovery
      @discovery ||= ActiveQueryExplorer.discovery_class.new
    end

    def executor
      @executor ||= ActiveQueryExplorer.executor_class.new
    end

    def serializer
      @serializer ||= ActiveQueryExplorer.serializer_class.new
    end
  end
end
