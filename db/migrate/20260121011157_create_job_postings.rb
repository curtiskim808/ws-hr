class CreateJobPostings < ActiveRecord::Migration[8.0]
  def change
    create_table :job_postings do |t|
      # Multi-tenant foreign key
      t.references :brand, null: false, foreign_key: true
      # Association to position template
      # NOTE: t.references automatically creates an index on position_template_id
      t.references :position_template, null: false, foreign_key: true

      t.timestamps
    end
  end
end
