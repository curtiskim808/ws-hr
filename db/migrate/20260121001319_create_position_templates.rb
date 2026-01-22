class CreatePositionTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :position_templates do |t|
      # Multi-tenant foreign key
      t.references :brand, null: false, foreign_key: true

      # Core template fields
      t.string :name, null: false
      t.string :job_title, null: false
      t.string :category, null: false
      t.string :department, null: false

      # Rich text fields
      t.text :description
      t.text :requirements

      # Job characteristics
      t.string :location_type
      t.string :employment_type
      t.string :education_requirement

      # Status: draft (0), active (1)
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    # Composite indexes for query performance
    # T034: These indexes optimize common queries

    # Filter by brand and status (e.g., "show me all active templates for this brand")
    add_index :position_templates, [ :brand_id, :status ]

    # Filter by brand and category (e.g., "show me all engineering templates")
    add_index :position_templates, [ :brand_id, :category ]

    # Sort by creation date within brand (e.g., "show me recent templates")
    add_index :position_templates, [ :brand_id, :created_at ]
  end
end
