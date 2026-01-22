# CreateJobPostings Migration - T059 & T060
#
# PURPOSE: Create job_postings table for published job listings
# WHY: Job postings are created from position templates and published to careers page
# BUSINESS LOGIC:
#   - Job posting references position_template (reuses template content)
#   - Each posting belongs to a location (onsite, remote, hybrid)
#   - Posting uses a hiring_process to define application workflow
#   - Status tracks lifecycle: draft → published → link_only → unpublished
#   - Timestamps track when posting was published/unpublished/closed
#
# EXAMPLE DATA:
#   - "Backend Engineer - SF" (template: Software Engineer, location: SF HQ, status: published)
#   - "Account Executive - Remote" (template: Sales Rep, location: Remote, status: published)
#   - "Support Specialist - NY" (template: Customer Support, location: NY Office, status: draft)
#
# STATE MACHINE (AASM):
#   draft → published → unpublished
#          ↓
#       link_only (hidden from careers page, accessible via direct link)
#
# MULTI-TENANT: brand_id foreign key ensures data isolation
class CreateJobPostings < ActiveRecord::Migration[8.0]
  def change
    create_table :job_postings do |t|
      # =============================================================================
      # MULTI-TENANT & ASSOCIATIONS
      # =============================================================================

      # MULTI-TENANT: Brand association for data isolation
      # REQUIRED: Every job posting belongs to exactly one brand
      # INDEX: Automatically created by t.references, part of composite indexes
      t.references :brand, null: false, foreign_key: true, index: true

      # TEMPLATE ASSOCIATION: Reuse position template content
      # REQUIRED: Job posting is created from a position template
      # WHY: Templates provide base content (title, description, requirements)
      # FLEXIBILITY: Job posting can customize template content
      # INDEX: Automatically created, also part of composite index
      t.references :position_template, null: false, foreign_key: true, index: true

      # LOCATION ASSOCIATION: Where is this job located?
      # REQUIRED: Every posting must have a location (onsite, remote, hybrid)
      # USE CASE: Filter jobs by location, group by office
      # INDEX: Automatically created, part of composite index
      t.references :location, null: false, foreign_key: true, index: true

      # HIRING PROCESS ASSOCIATION: Workflow for applications
      # REQUIRED: Defines stages applicants go through
      # DEFAULT: Uses brand's default hiring process
      # FLEXIBILITY: Can override with custom process for specific roles
      # INDEX: Automatically created
      t.references :hiring_process, null: false, foreign_key: true, index: true

      # =============================================================================
      # JOB POSTING CONTENT
      # =============================================================================

      # JOB TITLE: Position title (copied from template, can be customized)
      # REQUIRED: Displayed on careers page and in search results
      # EXAMPLE: "Senior Backend Engineer - Payments Team"
      # WHY COPY: Posting may need slight variation from template title
      t.string :job_title, null: false

      # DESCRIPTION: Full job description (copied from template, can be customized)
      # REQUIRED: Detailed explanation of role, responsibilities, team
      # FORMAT: Rich text (HTML or Markdown)
      # WHY COPY: Posting may include team-specific details
      t.text :description

      # REQUIREMENTS: Job requirements (copied from template, can be customized)
      # OPTIONAL: Skills, experience, education needed
      # FORMAT: Bullet points or paragraphs
      # WHY COPY: Posting may have specific requirements beyond template
      t.text :requirements

      # =============================================================================
      # STATUS & LIFECYCLE
      # =============================================================================

      # STATUS: Current state of job posting (AASM state machine)
      # ENUM VALUES (defined in model):
      #   - draft (0): Being prepared, not visible to public
      #   - published (1): Live on careers page, accepting applications
      #   - link_only (2): Hidden from careers page, accessible via direct link
      #   - unpublished (3): Removed from careers page, no longer accepting applications
      # DEFAULT: draft (all new postings start as drafts)
      # INDEX: Part of composite index (brand_id, status)
      t.integer :status, null: false, default: 0

      # =============================================================================
      # TIMESTAMPS
      # =============================================================================

      # PUBLISHED_AT: When posting was first published
      # NULLABLE: Only set when status changes to 'published'
      # USE CASE: Show "Posted X days ago" on careers page
      # AASM CALLBACK: Set automatically when publish! event fires
      t.datetime :published_at

      # UNPUBLISHED_AT: When posting was unpublished
      # NULLABLE: Only set when status changes to 'unpublished'
      # USE CASE: Track how long posting was live
      # AASM CALLBACK: Set automatically when unpublish! event fires
      t.datetime :unpublished_at

      # CLOSED_AT: When posting was manually closed (alternative to unpublish)
      # NULLABLE: Only set when admin explicitly closes posting
      # USE CASE: Distinguish between auto-close and manual close
      # NOTE: This is optional, may be used for reporting
      t.datetime :closed_at

      # STANDARD RAILS TIMESTAMPS
      # created_at: When posting was created (in draft state)
      # updated_at: When posting was last modified
      t.timestamps
    end

    # =============================================================================
    # T060: COMPOSITE INDEXES
    # =============================================================================
    # PURPOSE: Optimize common queries for performance

    # COMPOSITE INDEX: brand_id + status
    # PURPOSE: Fast lookup of postings by status for a brand
    # QUERY: SELECT * FROM job_postings WHERE brand_id = ? AND status = 'published'
    # USE CASE: List all published jobs on careers page
    # PERFORMANCE: O(log n) instead of O(n) table scan
    add_index :job_postings, [ :brand_id, :status ],
              name: 'index_job_postings_on_brand_and_status'

    # COMPOSITE INDEX: brand_id + location_id
    # PURPOSE: Fast lookup of postings by location for a brand
    # QUERY: SELECT * FROM job_postings WHERE brand_id = ? AND location_id = ?
    # USE CASE: Filter jobs by location (SF, NY, Remote, etc.)
    # PERFORMANCE: O(log n) lookup
    add_index :job_postings, [ :brand_id, :location_id ],
              name: 'index_job_postings_on_brand_and_location'

    # COMPOSITE INDEX: brand_id + published_at
    # PURPOSE: Fast sorting of postings by publish date
    # QUERY: SELECT * FROM job_postings WHERE brand_id = ? ORDER BY published_at DESC
    # USE CASE: Show newest jobs first on careers page
    # PERFORMANCE: O(log n) sorted retrieval
    add_index :job_postings, [ :brand_id, :published_at ],
              name: 'index_job_postings_on_brand_and_published_at'

    # INDEX: position_template_id
    # PURPOSE: Fast lookup of all postings created from a template
    # QUERY: SELECT * FROM job_postings WHERE position_template_id = ?
    # USE CASE: See all active job postings for a template
    # BUSINESS RULE: Prevents deleting templates with active postings
    # NOTE: Already created by t.references, but explicitly documented
    add_index :job_postings, :position_template_id,
              name: 'index_job_postings_on_position_template_id'
  end
end
