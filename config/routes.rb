Rails.application.routes.draw do
require 'sidekiq/web'


  mount Sidekiq::Web => '/sidekiq'


  get "up" => "rails/health#show", as: :rails_health_check

  
  get "shopify_products", to: "shopify_products#index"

  get "shopify_products/fetch_products", to: "shopify_products#fetch_products"
  get "shopify_products/update_prices", to: "shopify_products#update_prices"
end
