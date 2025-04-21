class CreateVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :sku
      t.string :shopify_id
      t.integer :inventory_quantity
      t.decimal :price
      t.timestamps
    end
    add_index :variants, :shopify_id, unique: true
  end
end
