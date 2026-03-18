# frozen_string_literal: true

ActiveQueryExplorer::Engine.routes.draw do
  resources :queries, only: [:index] do
    post :execute, on: :collection
  end

  root to: "queries#index"
end
