# CreateApplicants Migration - T079, T080, T081
#
# PURPOSE: Create applicants table for candidate records
# WHY: Applicants are individuals who apply for jobs (can apply to multiple postings)
# BUSINESS LOGIC:
#   - Applicant is a person (first_name, last_name, email, phone)
#   - Can apply to multiple job postings (one applicant → many applications)
#   - Email must be unique per brand (same person can exist in different brands)
#   - Can be flagged for review (flagged: true, flag_reason: text)
#   - Resume attached via ActiveStorage (not in this migration)
#
# EXAMPLE DATA:
#   - John Doe (john@example.com, phone: 555-0100, source: linkedin)
#   - Jane Smith (jane@example.com, phone: 555-0200, source: referral, flagged: true)
#
# MULTI-TENANT: brand_id foreign key ensures data isolation
class CreateApplicants < ActiveRecord::Migration[8.0]
  def change
    create_table :applicants do |t|
      # =============================================================================
      # MULTI-TENANT
      # =============================================================================

      # MULTI-TENANT: Brand association for data isolation
      # REQUIRED: Every applicant belongs to exactly one brand
      # INDEX: Automatically created by t.references, part of composite indexes
      t.references :brand, null: false, foreign_key: true, index: true

      # =============================================================================
      # PERSONAL INFORMATION
      # =============================================================================

      # FIRST NAME: Applicant's first name
      # REQUIRED: Essential for identification
      # EXAMPLE: "John", "Jane"
      # USE CASE: Display in application list, email communications
      t.string :first_name, null: false

      # LAST NAME: Applicant's last name
      # REQUIRED: Essential for identification
      # EXAMPLE: "Doe", "Smith"
      # USE CASE: Full name display, sorting by last name
      t.string :last_name, null: false

      # EMAIL: Applicant's email address
      # REQUIRED: Primary contact method
      # UNIQUE: Per brand (composite unique index)
      # FORMAT: Validated in model (email format validation)
      # EXAMPLE: "john.doe@example.com"
      # USE CASE: Communication, application notifications, login (future)
      t.string :email, null: false

      # PHONE: Applicant's phone number
      # OPTIONAL: Secondary contact method
      # FORMAT: Validated in model (phone format validation)
      # EXAMPLE: "+1-555-0100", "555-0100"
      # USE CASE: Interview scheduling, urgent communication
      t.string :phone

      # =============================================================================
      # PREFERENCES & METADATA
      # =============================================================================

      # PREFERRED LANGUAGE: Applicant's preferred communication language
      # DEFAULT: 'en' (English)
      # OPTIONAL: Used for localized email templates
      # EXAMPLE: 'en', 'es', 'fr', 'de'
      # USE CASE: Send rejection emails in applicant's language
      t.string :preferred_language, default: 'en'

      # SOURCE: How did the applicant find this job?
      # OPTIONAL: Track application sources for recruiting analytics
      # EXAMPLE: 'linkedin', 'referral', 'website', 'indeed', 'glassdoor'
      # USE CASE: Measure effectiveness of job boards, referral programs
      t.string :source

      # =============================================================================
      # FLAGGING SYSTEM
      # =============================================================================

      # FLAGGED: Is this applicant flagged for review?
      # DEFAULT: false
      # USE CASE: Flag spam, suspicious applications, duplicate candidates
      # WORKFLOW: Admin can flag applicant, preventing auto-processing
      t.boolean :flagged, default: false

      # FLAG REASON: Why was this applicant flagged?
      # OPTIONAL: Only set if flagged = true
      # EXAMPLE: "Duplicate application", "Spam", "Requires manual review"
      # USE CASE: Provide context to admins reviewing flagged applicants
      t.text :flag_reason

      # =============================================================================
      # TIMESTAMPS
      # =============================================================================

      # STANDARD RAILS TIMESTAMPS
      # created_at: When applicant record was created
      # updated_at: When applicant record was last modified
      t.timestamps
    end

    # =============================================================================
    # T080: COMPOSITE INDEX - brand_id + email (UNIQUE)
    # =============================================================================
    # PURPOSE: Ensure email uniqueness within a brand
    # QUERY: SELECT * FROM applicants WHERE brand_id = ? AND email = ?
    # USE CASE: Prevent duplicate applicant records in same brand
    # BUSINESS RULE: Same email can exist in different brands
    # PERFORMANCE: O(log n) lookup, enforces uniqueness
    #
    # EXAMPLE:
    #   Brand A: john@example.com (allowed)
    #   Brand A: john@example.com (rejected - duplicate)
    #   Brand B: john@example.com (allowed - different brand)
    add_index :applicants, [:brand_id, :email],
              unique: true,
              name: 'index_applicants_on_brand_and_email'

    # =============================================================================
    # T081: COMPOSITE INDEX - brand_id + created_at
    # =============================================================================
    # PURPOSE: Fast retrieval of recent applicants for a brand
    # QUERY: SELECT * FROM applicants WHERE brand_id = ? ORDER BY created_at DESC
    # USE CASE: List recent applicants, dashboard metrics
    # PERFORMANCE: O(log n) sorted retrieval
    #
    # EXAMPLE QUERY:
    #   Applicant.where(brand_id: 1).order(created_at: :desc).limit(10)
    add_index :applicants, [:brand_id, :created_at],
              name: 'index_applicants_on_brand_and_created_at'
  end
end
