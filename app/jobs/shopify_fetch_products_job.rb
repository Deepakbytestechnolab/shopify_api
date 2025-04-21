class ShopifyFetchProductsJob
  include Sidekiq::Job

  def perform(*args)
    ShopifyGraphqlClient.fetch_and_store_products
    ShopifyGraphqlClient.update_prices_based_on_sales

  end
end