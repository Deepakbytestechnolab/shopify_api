class ShopifyProductsController < ApplicationController
  # def index
  #   products = ShopifyGraphqlClient.fetch_products
  #   render json: { products: products }, status: :ok

  # end

  # def fetch_products
  #   ShopifyGraphqlClient.fetch_and_store_products
  #   render json: { message: "Products and variants fetched and saved!" }
  # end
   def fetch_products
    ShopifyGraphqlClient.fetch_and_store_products
    products = ShopifyGraphqlClient.fetch_products
    render json: { products: products }, status: :ok
  end

  def update_prices
    ShopifyGraphqlClient.update_prices_based_on_sales
    render json: { message: "Product prices updated based on sales!" }, status: :ok
  end
end
