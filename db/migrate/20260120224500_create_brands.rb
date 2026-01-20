class CreateBrands < ActiveRecord::Migration[8.0]
  def change
    create_table :brands do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.jsonb :settings, default: {}, null: false

      t.timestamps
    end

    # Indexes for performance and uniqueness
    add_index :brands, :subdomain, unique: true, name: 'index_brands_on_subdomain'
    add_index :brands, :name, name: 'index_brands_on_name'
  end
end
