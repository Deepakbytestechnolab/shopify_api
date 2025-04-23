class ShopifyGraphqlClient
  require 'shopify_api'
  require 'json'
  require 'net/http'
  require 'uri'

  SHOP_DOMAIN = ENV['SHOP_DOMAIN']
  ACCESS_TOKEN = ENV['ACCESS_TOKEN']

  PRODUCT_QUERY = <<~GRAPHQL
    query($cursor: String) {
      products(first: 250, after: $cursor) {
        edges {
          node {
            id
            title
            vendor
            status
            variants(first: 250) {
              edges {
                node {
                  id
                  sku
                  price
                  inventoryQuantity
                }
              }
            }
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  GRAPHQL

  UPDATE_PRICE_MUTATION = <<~GRAPHQL
    mutation UpdateVariantPrice($input: ProductVariantInput!) {
      productVariantUpdate(input: $input) {
        productVariant {
          id
          price
        }
        userErrors {
          field
          message
        }
      }
    }
  GRAPHQL

  class << self
    def fetch_products
      cursor = nil
      all_products = []

      loop do
        response = graphql_client.query(
          query: PRODUCT_QUERY,
          variables: { cursor: cursor }
        )

        body = response.body
        return [] if body["errors"] || body["data"].nil?

        edges = body.dig("data", "products", "edges") || []
        all_products += edges.map { |edge| edge["node"] }

        page_info = body.dig("data", "products", "pageInfo")
        break unless page_info && page_info["hasNextPage"]

        cursor = page_info["endCursor"]
      end

      all_products
    rescue => e
      Rails.logger.error("Shopify fetch_products error: #{e.message}")
      []
    end

    def fetch_and_store_products
      products = fetch_products

      products.each do |product|
        prod = Product.find_or_initialize_by(shopify_id: product["id"])
        prod.title = product["title"]
        prod.vendor = product["vendor"]
        prod.status = product["status"]
        prod.save!

        variants = product.dig("variants", "edges") || []

        variants.each do |variant_edge|
          variant_data = variant_edge["node"]
          inventory_qty = variant_data["inventoryQuantity"]

          prod.variants.find_or_initialize_by(shopify_id: variant_data["id"]).tap do |v|
            v.sku = variant_data["sku"]
            v.inventory_quantity = inventory_qty
            v.price = variant_data["price"].to_f
            v.save!
          end
        end
      end
    end

    def update_prices(type)
      case type
      when "sales_based"
        update_price_by_sales
      when "inventory_based"
        update_price_by_inventory
      when "both"
        update_price_by_sales_and_inventory
      else
        Rails.logger.error("Invalid price update type: #{type}")
      end
    end

    def update_price_by_sales
      Product.includes(:variants).find_each do |product|
        product.variants.each do |variant|
          sales = calculate_variant_sales_last_7_days(variant.shopify_id)
          Rails.logger.info "Variant #{variant.sku} sold #{sales} units in last 7 days"

          if sales >= 50
            new_price = (variant.price * 1.15).round(2)
            update_variant_price_if_changed(variant, new_price)
          end
        end
      end
    end

    def update_price_by_inventory
      Product.includes(:variants).find_each do |product|
        product.variants.each do |variant|
          price = variant.price

          if variant.inventory_quantity.to_i < 10
            new_price = (price * 1.10).round(2)
          elsif variant.inventory_quantity.to_i > 100
            new_price = (price * 0.95).round(2)
          else
            next
          end

          update_variant_price_if_changed(variant, new_price)
        end
      end
    end

    def update_price_by_sales_and_inventory
      byebug
      Product.includes(:variants).find_each do |product|
        product.variants.each do |variant|
          price = variant.price
          sales = calculate_variant_sales_last_7_days(variant.shopify_id)
          Rails.logger.info "Variant #{variant.sku} sold #{sales} units in last 7 days"

          new_price = price
          new_price *= 1.15 if sales >= 3

          if variant.inventory_quantity.to_i < 10
            new_price *= 1.10
          elsif variant.inventory_quantity.to_i > 100
            new_price *= 0.95
          end

          new_price = new_price.round(2)
          update_variant_price_if_changed(variant, new_price)
        end
      end
    end

    def update_variant_price_if_changed(variant, new_price)
      return if variant.price == new_price

      Rails.logger.info "Updating price for SKU #{variant.sku}: #{variant.price} → #{new_price}"
      variant.update(price: new_price)
      update_shopify_variant_price(variant.shopify_id, new_price)
    end

    def update_shopify_variant_price(variant_id, new_price)
      input = {
        id: variant_id,
        price: new_price.to_s
      }

      response = graphql_client.query(
        query: UPDATE_PRICE_MUTATION,
        variables: { input: input }
      )

      if response.body["errors"].present? || response.body.dig("data", "productVariantUpdate", "userErrors").present?
        Rails.logger.error("Failed to update variant price for #{variant_id}: #{response.body}")
      else
        Rails.logger.info("Successfully updated price for #{variant_id} to #{new_price}")
      end
    rescue => e
      Rails.logger.error("GraphQL error updating variant price: #{e.message}")
    end

    def calculate_variant_sales_last_7_days(variant_shopify_gid)
      variant_id = variant_shopify_gid.to_s.split('/').last
      orders = fetch_orders_last_7_days
      sold_count = 0

      orders.each do |order|
        (order["line_items"] || []).each do |line_item|
          line_variant_id = line_item["variant_id"].to_s
          sold_count += line_item["quantity"].to_i if line_variant_id == variant_id
        end
      end

      sold_count
    end

    def fetch_orders_last_7_days
      start_date = 7.days.ago.iso8601
      uri = URI("https://#{SHOP_DOMAIN}/admin/api/2024-01/orders.json?status=any&created_at_min=#{start_date}")
      request = Net::HTTP::Get.new(uri)
      request["X-Shopify-Access-Token"] = ACCESS_TOKEN

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.code == "200"
        json = JSON.parse(response.body)
        json["orders"] || []
      else
        Rails.logger.error "Failed to fetch orders: #{response.code} #{response.body}"
        []
      end
    rescue => e
      Rails.logger.error("Error in fetch_orders_last_7_days: #{e.message}")
      []
    end

    private

    def graphql_client
      @graphql_client ||= ShopifyAPI::Clients::Graphql::Admin.new(session: shopify_session)
    end

    def shopify_session
      shop = SHOP_DOMAIN
      token = ACCESS_TOKEN

      raise "SHOP or TOKEN is nil!" if shop.nil? || token.nil?

      ShopifyAPI::Auth::Session.new(shop: shop, access_token: token)
    end
  end
end
