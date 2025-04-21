class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :title
      t.string :vendor
      t.string :status
      t.string :shopify_id

      t.timestamps
    end
    add_index :products, :shopify_id, unique: true
  end
end
