# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_04_17_065459) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "products", force: :cascade do |t|
    t.string "title"
    t.string "vendor"
    t.string "status"
    t.string "shopify_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shopify_id"], name: "index_products_on_shopify_id", unique: true
  end

  create_table "variants", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "sku"
    t.string "shopify_id"
    t.integer "inventory_quantity"
    t.decimal "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_variants_on_product_id"
    t.index ["shopify_id"], name: "index_variants_on_shopify_id", unique: true
  end

  add_foreign_key "variants", "products"
end
