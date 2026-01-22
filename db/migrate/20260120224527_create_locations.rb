class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.references :brand, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :address
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country, default: 'US'
      t.string :timezone, null: false, default: 'UTC'

      t.timestamps
    end

    # Composite index for brand-scoped queries (performance optimization)
    add_index :locations, [ :brand_id, :name ], name: 'index_locations_on_brand_and_name'
    add_index :locations, [ :brand_id, :city, :state ], name: 'index_locations_on_brand_city_state'
  end
end
