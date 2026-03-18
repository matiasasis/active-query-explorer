# frozen_string_literal: true

module ActiveQueryExplorer
  class Engine < ::Rails::Engine
    isolate_namespace ActiveQueryExplorer

    initializer "active_query_explorer.assets" do |app|
      app.config.assets.paths << root.join("app", "assets", "stylesheets")
      app.config.assets.paths << root.join("app", "assets", "javascripts")
      app.config.assets.precompile += %w[
        active_query_explorer/application.css
        active_query_explorer/application.js
      ]
    end

    initializer "active_query_explorer.eager_load_queries" do
      ActiveSupport.on_load(:after_initialize) do
        ActiveQueryExplorer.query_paths.each do |dir|
          # Standard Rails app paths
          path = Rails.root.join("app", dir)
          Rails.autoloaders.main.eager_load_dir(path.to_s) if path.exist?

          # Packwerk / packs paths (packs/**/app/queries)
          Dir.glob(Rails.root.join("packs", "**", "app", dir).to_s).each do |pack_path|
            Rails.autoloaders.main.eager_load_dir(pack_path) if File.directory?(pack_path)
          end
        end
      end
    end
  end
end
