# frozen_string_literal: true

module ActiveQueryExplorer
  class QueriesController < ActionController::Base
    layout false

    def index
      respond_to do |format|
        format.html
        format.json { render json: discovery.grouped_queries }
      end
    end

    def execute
      klass = discovery.find_query_class!(params[:query_class])
      query_name = params[:query_name].to_sym
      query_def = discovery.find_query_def!(klass, query_name)

      result = executor.execute(klass, query_name, params[:args], query_def[:args_def] || {})

      render json: { result: serializer.serialize(result) }
    rescue ArgumentError, NameError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue => e
      render json: { error: "#{e.class}: #{e.message}" }, status: :internal_server_error
    end

    private

    def discovery
      @discovery ||= QueryDiscovery.new
    end

    def executor
      @executor ||= QueryExecutor.new
    end

    def serializer
      @serializer ||= ResultSerializer.new
    end
  end
end
