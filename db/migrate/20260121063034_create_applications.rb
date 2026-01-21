# CreateApplications Migration - T087, T088
#
# PURPOSE: Create applications table for job applications
# WHY: Applications represent an applicant applying to a specific job posting
# BUSINESS LOGIC:
#   - One applicant can have multiple applications (to different job postings)
#   - Application follows a hiring_process with stages
#   - Application has status: in_progress, hired, rejected, archived
#   - Timestamps track lifecycle: applied_at, hired_at, rejected_at
#   - Hiring/rejection decisions recorded with user_id
#
# EXAMPLE DATA:
#   - John Doe applied for "Backend Engineer" (status: in_progress, current_stage: phone_screen)
#   - Jane Smith applied for "Sales Rep" (status: hired, hired_at: 2026-01-15, hired_by: admin_user)
#   - Bob Jones applied for "Support" (status: rejected, rejection_reason: "Not enough experience")
#
# STATE MACHINE (AASM):
#   in_progress (default) → hired
#                        → rejected
#                        → archived
#
# MULTI-TENANT: brand_id foreign key ensures data isolation
class CreateApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :applications do |t|
      # =============================================================================
      # MULTI-TENANT & CORE ASSOCIATIONS
      # =============================================================================

      # MULTI-TENANT: Brand association for data isolation
      # REQUIRED: Every application belongs to exactly one brand
      # INDEX: Automatically created by t.references, part of composite indexes
      t.references :brand, null: false, foreign_key: true, index: true

      # APPLICANT: Who is applying?
      # REQUIRED: Every application must have an applicant
      # RELATIONSHIP: belongs_to :applicant
      # BUSINESS RULE: Same applicant can apply to multiple job postings
      # INDEX: Part of unique composite index (applicant_id, job_posting_id)
      t.references :applicant, null: false, foreign_key: true, index: true

      # JOB POSTING: What job are they applying for?
      # REQUIRED: Every application is for a specific job posting
      # RELATIONSHIP: belongs_to :job_posting
      # BUSINESS RULE: One applicant can only apply once per job posting
      # INDEX: Part of composite indexes
      t.references :job_posting, null: false, foreign_key: true, index: true

      # HIRING PROCESS: What workflow does this application follow?
      # REQUIRED: Copied from job_posting.hiring_process at creation
      # WHY: Hiring process defines stages applicant progresses through
      # IMMUTABLE: Once application is created, hiring_process doesn't change
      # INDEX: Automatically created for foreign key lookups
      t.references :hiring_process, null: false, foreign_key: true, index: true

      # CURRENT STAGE: What stage is the applicant at?
      # OPTIONAL: Can be null initially (before application review starts)
      # RELATIONSHIP: belongs_to :current_stage, class_name: 'HiringStage'
      # BUSINESS RULE: Must be a stage that belongs to this application's hiring_process
      # USE CASE: Track application progress (Application Review → Phone Screen → Interview)
      t.references :current_stage, foreign_key: { to_table: :hiring_stages }, index: true

      # =============================================================================
      # STATUS & LIFECYCLE
      # =============================================================================

      # STATUS: Current state of application (AASM state machine)
      # ENUM VALUES (defined in model):
      #   - in_progress (0): Application being reviewed/processed
      #   - hired (1): Applicant was hired
      #   - rejected (2): Applicant was rejected
      #   - archived (3): Application archived (no longer active)
      # DEFAULT: in_progress (all new applications start in progress)
      # INDEX: Part of composite index (brand_id, status)
      t.integer :status, null: false, default: 0

      # =============================================================================
      # TIMESTAMPS - APPLICATION LIFECYCLE
      # =============================================================================

      # APPLIED_AT: When did the applicant submit this application?
      # REQUIRED: Set at creation (defaults to Time.current)
      # USE CASE: Show "Applied 5 days ago", sort by application date
      # BUSINESS RULE: Cannot be changed after creation
      t.datetime :applied_at, null: false

      # HIRED_AT: When was the applicant hired?
      # NULLABLE: Only set when status changes to 'hired'
      # AASM CALLBACK: Set automatically when hire! event fires
      # USE CASE: Track time-to-hire metrics
      t.datetime :hired_at

      # HIRED_BY: Which user made the hiring decision?
      # NULLABLE: Only set when status changes to 'hired'
      # RELATIONSHIP: belongs_to :hired_by, class_name: 'User'
      # USE CASE: Audit trail, who hired this applicant
      t.references :hired_by, foreign_key: { to_table: :users }, index: true

      # REJECTED_AT: When was the applicant rejected?
      # NULLABLE: Only set when status changes to 'rejected'
      # AASM CALLBACK: Set automatically when reject! event fires
      # USE CASE: Track rejection timeline, analytics
      t.datetime :rejected_at

      # REJECTED_BY: Which user made the rejection decision?
      # NULLABLE: Only set when status changes to 'rejected'
      # RELATIONSHIP: belongs_to :rejected_by, class_name: 'User'
      # USE CASE: Audit trail, who rejected this applicant
      t.references :rejected_by, foreign_key: { to_table: :users }, index: true

      # REJECTION REASON: Why was the applicant rejected?
      # NULLABLE: Only set when status changes to 'rejected'
      # EXAMPLE: "Not enough experience", "Position filled", "Cultural fit"
      # USE CASE: Provide feedback, improve hiring process, analytics
      t.text :rejection_reason

      # ARCHIVED_AT: When was the application archived?
      # NULLABLE: Only set when status changes to 'archived'
      # USE CASE: Track when old applications were archived
      t.datetime :archived_at

      # =============================================================================
      # NOTES & METADATA
      # =============================================================================

      # NOTES: Internal notes about this application
      # OPTIONAL: Free-form text for recruiters/hiring managers
      # EXAMPLE: "Strong technical skills, good culture fit", "Needs follow-up call"
      # USE CASE: Collaboration between hiring team members
      t.text :notes

      # =============================================================================
      # TIMESTAMPS
      # =============================================================================

      # STANDARD RAILS TIMESTAMPS
      # created_at: When application record was created
      # updated_at: When application record was last modified
      t.timestamps
    end

    # =============================================================================
    # T088: COMPOSITE INDEXES
    # =============================================================================

    # COMPOSITE INDEX: brand_id + status
    # PURPOSE: Fast lookup of applications by status for a brand
    # QUERY: SELECT * FROM applications WHERE brand_id = ? AND status = 'in_progress'
    # USE CASE: Dashboard showing all in-progress applications
    # PERFORMANCE: O(log n) instead of O(n) table scan
    add_index :applications, [:brand_id, :status],
              name: 'index_applications_on_brand_and_status'

    # COMPOSITE INDEX: brand_id + job_posting_id
    # PURPOSE: Fast lookup of all applications for a job posting
    # QUERY: SELECT * FROM applications WHERE brand_id = ? AND job_posting_id = ?
    # USE CASE: View all applicants for "Backend Engineer" posting
    # PERFORMANCE: O(log n) lookup
    add_index :applications, [:brand_id, :job_posting_id],
              name: 'index_applications_on_brand_and_job_posting'

    # COMPOSITE INDEX: brand_id + applicant_id
    # PURPOSE: Fast lookup of all applications by an applicant
    # QUERY: SELECT * FROM applications WHERE brand_id = ? AND applicant_id = ?
    # USE CASE: View application history for John Doe
    # PERFORMANCE: O(log n) lookup
    add_index :applications, [:brand_id, :applicant_id],
              name: 'index_applications_on_brand_and_applicant'

    # COMPOSITE INDEX: brand_id + created_at
    # PURPOSE: Fast retrieval of recent applications
    # QUERY: SELECT * FROM applications WHERE brand_id = ? ORDER BY created_at DESC
    # USE CASE: Dashboard showing recent applications
    # PERFORMANCE: O(log n) sorted retrieval
    add_index :applications, [:brand_id, :created_at],
              name: 'index_applications_on_brand_and_created_at'

    # COMPOSITE INDEX: applicant_id + job_posting_id (UNIQUE)
    # PURPOSE: Prevent duplicate applications
    # QUERY: Enforce business rule - one applicant can only apply once per job
    # BUSINESS RULE: Same applicant cannot apply twice to the same job posting
    # PERFORMANCE: O(log n) lookup, enforces uniqueness
    #
    # EXAMPLE:
    #   John Doe → "Backend Engineer" (allowed)
    #   John Doe → "Backend Engineer" (rejected - duplicate)
    #   John Doe → "Frontend Engineer" (allowed - different job)
    add_index :applications, [:applicant_id, :job_posting_id],
              unique: true,
              name: 'index_applications_on_applicant_and_job_posting'
  end
end
