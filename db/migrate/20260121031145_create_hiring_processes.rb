# CreateHiringProcesses Migration - T051
#
# PURPOSE: Create hiring_processes table to define hiring workflows
# WHY: Each brand can have multiple hiring processes (default + custom)
# BUSINESS LOGIC:
#   - HiringProcess defines the stages an application goes through
#   - Each brand has one default process (is_default: true)
#   - Custom processes can be created for specific roles/departments
#   - Active/inactive flag allows archiving old processes
#
# EXAMPLE DATA:
#   - Acme Brand: "Standard Hiring" (default, active)
#     Stages: Application → Phone Screen → Technical Interview → Offer
#   - Acme Brand: "Executive Hiring" (custom, active)
#     Stages: Application → Executive Interview → Background Check → Offer
#
# MULTI-TENANT: brand_id foreign key ensures data isolation
class CreateHiringProcesses < ActiveRecord::Migration[8.0]
  def change
    create_table :hiring_processes do |t|
      # MULTI-TENANT: Brand association for data isolation
      # REQUIRED: Every hiring process belongs to exactly one brand
      # INDEX: Part of composite indexes for fast brand-scoped queries
      t.references :brand, null: false, foreign_key: true, index: true

      # PROCESS IDENTIFICATION
      # name: Human-readable process name (e.g., "Standard Hiring", "Executive Hiring")
      # REQUIRED: Used in UI to select hiring process for job posting
      t.string :name, null: false

      # PROCESS DESCRIPTION
      # description: Detailed explanation of when to use this process
      # OPTIONAL: Helps hiring managers choose appropriate process
      # EXAMPLE: "Use for all engineering roles requiring technical assessment"
      t.text :description

      # DEFAULT PROCESS FLAG
      # is_default: One process per brand should be marked as default
      # BUSINESS RULE: Job postings use default process unless specified
      # VALIDATION: Enforced at model level (one default per brand)
      t.boolean :is_default, default: false, null: false

      # ACTIVE STATUS
      # active: Controls whether process can be used for new job postings
      # SOFT DELETE: Inactive processes remain in DB for historical applications
      # DEFAULT: true (new processes are active by default)
      t.boolean :active, default: true, null: false

      # TIMESTAMPS
      # created_at: When process was created
      # updated_at: When process was last modified
      t.timestamps
    end

    # COMPOSITE INDEX: brand_id + is_default
    # PURPOSE: Fast lookup of default process for a brand
    # QUERY: SELECT * FROM hiring_processes WHERE brand_id = ? AND is_default = true
    # PERFORMANCE: O(1) lookup instead of table scan
    add_index :hiring_processes, [:brand_id, :is_default],
              name: 'index_hiring_processes_on_brand_and_default'

    # COMPOSITE INDEX: brand_id + active
    # PURPOSE: Fast lookup of active processes for a brand
    # QUERY: SELECT * FROM hiring_processes WHERE brand_id = ? AND active = true
    # USE CASE: Dropdown list when creating job posting
    add_index :hiring_processes, [:brand_id, :active],
              name: 'index_hiring_processes_on_brand_and_active'
  end
end
