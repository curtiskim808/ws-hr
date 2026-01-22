class AddMissingColumnsToJobPostings < ActiveRecord::Migration[8.0]
  def change
    # Add missing foreign key columns
    add_reference :job_postings, :location, null: false, foreign_key: true, index: true
    add_reference :job_postings, :hiring_process, null: false, foreign_key: true, index: true

    # Add missing content columns
    add_column :job_postings, :job_title, :string, null: false
    add_column :job_postings, :description, :text
    add_column :job_postings, :requirements, :text

    # Add missing status and lifecycle columns
    add_column :job_postings, :status, :integer, null: false, default: 0
    add_column :job_postings, :published_at, :datetime
    add_column :job_postings, :unpublished_at, :datetime
    add_column :job_postings, :closed_at, :datetime

    # Add missing composite indexes
    add_index :job_postings, [ :brand_id, :status ], name: 'index_job_postings_on_brand_and_status'
    add_index :job_postings, [ :brand_id, :location_id ], name: 'index_job_postings_on_brand_and_location'
    add_index :job_postings, [ :brand_id, :published_at ], name: 'index_job_postings_on_brand_and_published_at'
  end
end
