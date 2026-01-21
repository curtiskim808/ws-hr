# Applicant Model - T082-T086
#
# PURPOSE: Represent individuals who apply for jobs
# WHY: Applicants are candidates who submit applications to job postings
# BUSINESS LOGIC:
#   - One applicant can submit multiple applications (to different job postings)
#   - Email must be unique within a brand
#   - Resume attached via ActiveStorage
#   - Can be flagged for manual review (spam, duplicates, etc.)
#
# EXAMPLE SCENARIOS:
#   1. John Doe applies for "Backend Engineer" job (creates applicant + application)
#   2. John Doe later applies for "Frontend Engineer" job (reuses applicant, creates new application)
#   3. Admin flags suspicious applicant for review
#
# MULTI-TENANT: Automatic brand scoping via BrandScoped concern
class Applicant < ApplicationRecord
  # MULTI-TENANT SCOPING
  # PURPOSE: Automatically scope all queries by Current.brand
  # RESULT: Users only see applicants from their brand
  # IMPLEMENTATION: Adds default_scope and sets brand_id on create
  include BrandScoped

  # =============================================================================
  # T083: ASSOCIATIONS
  # =============================================================================

  # PARENT: Brand
  # REQUIREMENT: Every applicant belongs to exactly one brand
  # VALIDATION: Presence enforced by database (null: false)
  belongs_to :brand

  # CHILDREN: Applications
  # PURPOSE: All applications submitted by this applicant
  # CASCADE: When applicant is deleted, all applications are deleted
  # BUSINESS RULE: Deleting applicant removes all their application history
  # INVERSE: Each application belongs_to one applicant
  has_many :applications, dependent: :destroy

  # =============================================================================
  # T086: ACTIVESTORAGE - RESUME ATTACHMENT
  # =============================================================================
  # PURPOSE: Attach applicant's resume PDF/DOC file
  # VALIDATION: File type (pdf, doc, docx) and size (< 5MB)
  # STORAGE: Amazon S3 or local disk (configured in storage.yml)
  # USE CASE: Recruiters download and review resumes
  #
  # USAGE:
  #   applicant.resume.attach(params[:resume])
  #   applicant.resume.attached? # => true
  #   applicant.resume.download   # => binary file data
  #   applicant.resume.purge      # => delete file
  has_one_attached :resume

  # =============================================================================
  # T082: VALIDATIONS
  # =============================================================================

  # REQUIRED FIELDS
  # first_name: Applicant's first name
  # last_name: Applicant's last name
  # email: Applicant's email address
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true

  # EMAIL FORMAT VALIDATION
  # PURPOSE: Ensure email is valid format
  # REGEX: Standard email format (user@domain.tld)
  # EXAMPLE: Valid - "john@example.com", Invalid - "john@", "john"
  # WHY: Prevent invalid emails from being saved
  validates :email, format: {
    with: URI::MailTo::EMAIL_REGEXP,
    message: 'must be a valid email address'
  }

  # EMAIL UNIQUENESS VALIDATION (within brand)
  # PURPOSE: Prevent duplicate applicant records
  # SCOPE: brand_id (same email can exist in different brands)
  # DATABASE: Enforced by unique composite index (brand_id, email)
  # EXAMPLE:
  #   Brand A: john@example.com (allowed)
  #   Brand A: john@example.com (rejected - duplicate)
  #   Brand B: john@example.com (allowed - different brand)
  validates :email, uniqueness: {
    scope: :brand_id,
    message: 'has already applied (duplicate applicant in this brand)'
  }

  # PHONE FORMAT VALIDATION (optional, only if present)
  # PURPOSE: Ensure phone number is valid format
  # REGEX: Flexible format (allows +1-555-0100, 555-0100, (555) 010-0100, etc.)
  # WHY: Basic validation to catch obvious typos
  # OPTIONAL: Only validates if phone is present
  validates :phone, format: {
    with: /\A[\d\s\-\(\)\+\.]+\z/,
    message: 'must be a valid phone number'
  }, allow_blank: true

  # =============================================================================
  # T086: RESUME VALIDATION
  # =============================================================================
  # PURPOSE: Validate resume file type and size
  # ALLOWED TYPES: PDF, DOC, DOCX
  # MAX SIZE: 5MB
  # WHY: Prevent large files, ensure recruiters can open resumes
  validate :resume_validation, if: -> { resume.attached? }

  # =============================================================================
  # T084: HELPER METHODS
  # =============================================================================

  # METHOD: full_name
  # PURPOSE: Get applicant's full name
  # RETURNS: String "First Last"
  # USE CASE: Display in UI, email templates, reports
  #
  # EXAMPLE:
  #   applicant = Applicant.new(first_name: "John", last_name: "Doe")
  #   applicant.full_name
  #   => "John Doe"
  def full_name
    "#{first_name} #{last_name}"
  end

  # =============================================================================
  # T085: SCOPES
  # =============================================================================

  # SCOPE: recent
  # PURPOSE: Get applicants ordered by most recent first
  # QUERY: SELECT * FROM applicants WHERE brand_id = ? ORDER BY created_at DESC
  # USE CASE: Dashboard showing recent applicants
  # PERFORMANCE: Uses composite index (brand_id, created_at)
  #
  # EXAMPLE:
  #   Applicant.recent.limit(10)
  #   => [#<Applicant id: 3>, #<Applicant id: 2>, #<Applicant id: 1>]
  scope :recent, -> { order(created_at: :desc) }

  # SCOPE: flagged
  # PURPOSE: Get applicants flagged for review
  # QUERY: SELECT * FROM applicants WHERE brand_id = ? AND flagged = true
  # USE CASE: Admin reviews flagged applicants (spam, duplicates)
  # RETURNS: ActiveRecord::Relation
  #
  # EXAMPLE:
  #   Applicant.flagged
  #   => [#<Applicant id: 5, flagged: true, flag_reason: "Suspicious application">]
  scope :flagged, -> { where(flagged: true) }

  # SCOPE: by_source
  # PURPOSE: Filter applicants by source (linkedin, referral, etc.)
  # QUERY: SELECT * FROM applicants WHERE brand_id = ? AND source = ?
  # USE CASE: Analytics - which sources bring the most applicants
  # PARAMETER: source - string (e.g., 'linkedin', 'referral')
  #
  # EXAMPLE:
  #   Applicant.by_source('linkedin')
  #   => [#<Applicant id: 1, source: 'linkedin'>, ...]
  #
  #   Applicant.by_source('referral').count
  #   => 15
  scope :by_source, ->(source) { where(source: source) }

  # =============================================================================
  # PRIVATE METHODS
  # =============================================================================

  private

  # PRIVATE METHOD: resume_validation
  # PURPOSE: Validate resume file type and size
  # IMPLEMENTATION:
  #   - Check content_type is pdf, doc, or docx
  #   - Check file size is less than 5MB
  # ERRORS: Adds validation errors to resume attribute
  def resume_validation
    return unless resume.attached?

    # Validate content type
    unless resume.content_type.in?(%w[application/pdf application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document])
      errors.add(:resume, 'must be a PDF, DOC, or DOCX file')
    end

    # Validate file size (< 5MB)
    if resume.byte_size > 5.megabytes
      errors.add(:resume, 'must be less than 5MB')
    end
  end
end
