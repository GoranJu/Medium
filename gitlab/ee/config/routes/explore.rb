# frozen_string_literal: true

namespace :explore do
  resources :dependencies, only: [:index]
end
