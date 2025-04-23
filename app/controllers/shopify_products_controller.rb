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
    type = params[:type]

    if %w[sales_based inventory_based both].include?(type)
      ShopifyGraphqlClient.update_prices(type)
      render json: { message: "Product prices updated using type: #{type}" }, status: :ok
    else
      render json: { error: "Invalid type. Allowed values: sales_based, inventory_based, both" }, status: :unprocessable_entity
    end
  end
end
