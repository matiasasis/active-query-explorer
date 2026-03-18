# frozen_string_literal: true

ActiveQueryExplorer::Engine.routes.draw do
  resources :queries, only: [:index]

  root to: "queries#index"
end
