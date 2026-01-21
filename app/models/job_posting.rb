# JobPosting Model - T061-T066
#
# PURPOSE: Represent published job listings on the careers page
# WHY: Job postings are created from position templates and published to attract candidates
# BUSINESS LOGIC:
#   - Created from position_template (reuses content, can customize)
#   - Belongs to a location (SF HQ, Remote, NY Office, etc.)
#   - Uses a hiring_process to define application workflow
#   - Has lifecycle states: draft → published → link_only/unpublished
#   - Timestamps track when posted, unpublished, closed
#
# STATE MACHINE (AASM):
#   draft (default) → publish! → published
#   published → unpublish! → unpublished
#   published → make_link_only! → link_only
#   link_only → publish! → published
#
# EXAMPLE SCENARIOS:
#   1. Create draft posting from template
#   2. Review and customize job title/description
#   3. Publish to careers page (status: published, sets published_at)
#   4. Hide from careers but keep link active (status: link_only)
#   5. Unpublish when position filled (status: unpublished, sets unpublished_at)
#
# MULTI-TENANT: Automatic brand scoping via BrandScoped concern
class JobPosting < ApplicationRecord
  # MULTI-TENANT SCOPING
  # PURPOSE: Automatically scope all queries by Current.brand
  # RESULT: Users only see job postings from their brand
  # IMPLEMENTATION: Adds default_scope and sets brand_id on create
  include BrandScoped

  # STATE MACHINE
  # PURPOSE: Manage job posting lifecycle with explicit state transitions
  # WHY: Prevent invalid state changes, track lifecycle events
  # LIBRARY: AASM (Acts As State Machine) gem
  include AASM

  # =============================================================================
  # ASSOCIATIONS
  # =============================================================================

  # PARENT: Brand
  # REQUIREMENT: Every job posting belongs to exactly one brand
  # VALIDATION: Presence enforced by database (null: false)
  belongs_to :brand

  # TEMPLATE: PositionTemplate
  # PURPOSE: Reuse position template content (title, description, requirements)
  # FLEXIBILITY: Posting can customize template content
  # WHY: Templates are reusable, postings are specific instances
  # EXAMPLE: "Software Engineer" template → "Backend Engineer - Payments" posting
  belongs_to :position_template

  # LOCATION: Location
  # PURPOSE: Where is this job located? (SF HQ, Remote, NY Office, etc.)
  # USE CASE: Filter jobs by location, group by office
  # VALIDATION: Required (every posting must have a location)
  belongs_to :location

  # HIRING PROCESS: HiringProcess
  # PURPOSE: Defines application workflow stages
  # DEFAULT: Uses brand's default hiring process
  # FLEXIBILITY: Can override with custom process for specific roles
  belongs_to :hiring_process

  # APPLICATIONS: Applications
  # PURPOSE: Candidates who applied to this job posting
  # CASCADE: When posting is deleted, applications are NOT deleted (preserve data)
  # RESTRICTION: Cannot delete posting if applications exist
  has_many :applications, dependent: :restrict_with_error

  # =============================================================================
  # T062: AASM STATE MACHINE
  # =============================================================================
  # PURPOSE: Manage job posting lifecycle with state transitions
  # STATES:
  #   - draft: Being prepared, not visible to public
  #   - published: Live on careers page, accepting applications
  #   - link_only: Hidden from careers page, accessible via direct link
  #   - unpublished: Removed from careers page, no longer accepting applications
  #
  # TRANSITIONS:
  #   draft → published (publish!)
  #   published → link_only (make_link_only!)
  #   published → unpublished (unpublish!)
  #   link_only → published (publish!)
  #
  # WHY STATE MACHINE:
  #   - Explicit state transitions prevent invalid states
  #   - Callbacks automatically update timestamps
  #   - Guards prevent invalid transitions
  #   - Auditable state changes

  aasm column: :status, enum: true do
    # STATE: draft
    # INITIAL STATE: All new job postings start as drafts
    # VISIBLE: Only to internal users (admins, hiring managers)
    # APPLICATIONS: Cannot apply (posting not published)
    # NEXT STATES: published
    state :draft, initial: true

    # STATE: published
    # VISIBLE: On careers page, search engines, job boards
    # APPLICATIONS: Accepting applications
    # NEXT STATES: link_only, unpublished
    state :published

    # STATE: link_only
    # VISIBLE: Only via direct link (not on careers page)
    # APPLICATIONS: Accepting applications
    # USE CASE: Soft launch, internal referrals, targeted campaigns
    # NEXT STATES: published, unpublished
    state :link_only

    # STATE: unpublished
    # VISIBLE: Only to internal users (for historical reference)
    # APPLICATIONS: Not accepting applications
    # USE CASE: Position filled, posting closed
    # NEXT STATES: None (terminal state)
    state :unpublished

    # =============================================================================
    # T063: AASM EVENTS (STATE TRANSITIONS)
    # =============================================================================

    # EVENT: publish!
    # PURPOSE: Make job posting live on careers page
    # FROM STATES: draft, link_only
    # TO STATE: published
    # GUARD: Must have hiring_process (enforced by validation)
    # CALLBACK: Sets published_at timestamp (if first publish)
    #
    # EXAMPLE:
    #   posting = JobPosting.create!(title: "Engineer", status: :draft)
    #   posting.publish!
    #   posting.status          # => "published"
    #   posting.published_at    # => 2026-01-21 10:30:00 UTC
    event :publish, after: :record_published_at do
      transitions from: [:draft, :link_only], to: :published,
                  guard: :has_hiring_process?
    end

    # EVENT: unpublish!
    # PURPOSE: Remove job posting from careers page
    # FROM STATES: published, link_only
    # TO STATE: unpublished
    # CALLBACK: Sets unpublished_at timestamp
    # USE CASE: Position filled, posting expired
    #
    # EXAMPLE:
    #   posting.unpublish!
    #   posting.status            # => "unpublished"
    #   posting.unpublished_at    # => 2026-01-21 10:30:00 UTC
    event :unpublish, after: :record_unpublished_at do
      transitions from: [:published, :link_only], to: :unpublished
    end

    # EVENT: make_link_only!
    # PURPOSE: Hide from careers page but keep accessible via direct link
    # FROM STATES: published
    # TO STATE: link_only
    # USE CASE: Soft launch, limit visibility, internal referrals
    #
    # EXAMPLE:
    #   posting.make_link_only!
    #   posting.status    # => "link_only"
    #   # Can still apply via direct URL, but not listed on careers page
    event :make_link_only do
      transitions from: :published, to: :link_only
    end
  end

  # =============================================================================
  # T065: VALIDATIONS
  # =============================================================================

  # REQUIRED FIELDS
  # job_title: Position title displayed on careers page
  # REASON: Essential for job seekers to understand the role
  validates :job_title, presence: true

  # BUSINESS RULE: Must have hiring_process before publishing
  # WHY: Applications need a workflow to follow
  # WHEN: Only enforced when status is 'published'
  # GUARD: Used in AASM publish! event guard
  validates :hiring_process, presence: { message: 'must be set before publishing' },
                            if: :published?

  # =============================================================================
  # T064: SCOPES
  # =============================================================================

  # SCOPE: published
  # PURPOSE: Get all published job postings
  # QUERY: SELECT * FROM job_postings WHERE status = 'published'
  # USE CASE: Display jobs on careers page
  # PERFORMANCE: Uses composite index (brand_id, status)
  #
  # EXAMPLE:
  #   JobPosting.published
  #   => [#<JobPosting id: 1, title: "Backend Engineer">, #<JobPosting id: 2, title: "Sales Rep">]
  scope :published, -> { where(status: :published) }

  # SCOPE: at_location
  # PURPOSE: Filter postings by location
  # QUERY: SELECT * FROM job_postings WHERE location_id = ?
  # USE CASE: Show jobs for specific office (SF, NY, Remote)
  # PERFORMANCE: Uses composite index (brand_id, location_id)
  #
  # EXAMPLE:
  #   sf_location = Location.find_by(name: "San Francisco HQ")
  #   JobPosting.at_location(sf_location.id)
  #   => [#<JobPosting id: 1, title: "Backend Engineer - SF">]
  scope :at_location, ->(location_id) { where(location_id: location_id) }

  # SCOPE: recent
  # PURPOSE: Get postings ordered by most recently published
  # QUERY: SELECT * FROM job_postings ORDER BY published_at DESC
  # USE CASE: Show newest jobs first on careers page
  # PERFORMANCE: Uses composite index (brand_id, published_at)
  #
  # EXAMPLE:
  #   JobPosting.published.recent.limit(10)
  #   => [#<JobPosting published_at: "2026-01-21">, #<JobPosting published_at: "2026-01-20">]
  scope :recent, -> { order(published_at: :desc) }

  # SCOPE: published_cached
  # PURPOSE: Cache published postings for performance
  # QUERY: Fetches from Redis cache, falls back to database
  # CACHE KEY: Scoped by brand_id for multi-tenancy
  # EXPIRATION: 1 hour (careers page is relatively static)
  # INVALIDATION: Via after_commit callback when status changes
  #
  # EXAMPLE:
  #   JobPosting.published_cached
  #   # First call: queries database, caches result
  #   # Subsequent calls: returns cached data (much faster)
  scope :published_cached, -> {
    Rails.cache.fetch("job_postings/published/#{Current.brand&.id}", expires_in: 1.hour) do
      published.to_a
    end
  }

  # =============================================================================
  # CALLBACKS
  # =============================================================================

  # CALLBACK: Set default hiring_process
  # TRIGGER: Before validation on create
  # ACTION: Use brand's default hiring process if not specified
  # WHY: Most postings use standard hiring workflow
  before_validation :set_default_hiring_process, on: :create

  # CALLBACK: Copy content from position_template
  # TRIGGER: Before validation on create
  # ACTION: Copy job_title, description, requirements from template
  # WHY: Templates provide base content, postings can customize
  # FLEXIBILITY: Values are copied, not referenced (posting-specific edits allowed)
  before_validation :copy_from_template, on: :create

  # T066: CALLBACK: Invalidate cache on status change
  # TRIGGER: After commit (after transaction completes)
  # ACTION: Delete cached published postings when status changes
  # WHY: Cache becomes stale when posting is published/unpublished
  # TRANSACTION SAFETY: Uses after_commit (not after_save) to prevent phantom invalidations
  after_commit :invalidate_published_cache, if: :saved_change_to_status?

  # =============================================================================
  # BUSINESS LOGIC METHODS
  # =============================================================================

  # METHOD: days_since_published
  # PURPOSE: Calculate how many days ago posting was published
  # RETURNS: Integer (days) or nil if not published
  # USE CASE: Display "Posted 5 days ago" on careers page
  #
  # EXAMPLE:
  #   posting.days_since_published
  #   => 5
  def days_since_published
    return nil unless published_at
    ((Time.current - published_at) / 1.day).floor
  end

  # METHOD: accepting_applications?
  # PURPOSE: Check if posting is currently accepting applications
  # RETURNS: Boolean
  # BUSINESS RULE: Published or link_only postings accept applications
  #
  # EXAMPLE:
  #   posting.accepting_applications?
  #   => true
  def accepting_applications?
    published? || link_only?
  end

  # METHOD: visible_on_careers_page?
  # PURPOSE: Check if posting appears on public careers page
  # RETURNS: Boolean
  # BUSINESS RULE: Only published postings appear on careers page
  #
  # EXAMPLE:
  #   posting.visible_on_careers_page?
  #   => true
  def visible_on_careers_page?
    published?
  end

  private

  # PRIVATE METHOD: set_default_hiring_process
  # PURPOSE: Auto-assign default hiring process if not specified
  # IMPLEMENTATION: Use brand's default process, or first active process
  # TRANSACTION: Runs before validation within same transaction
  def set_default_hiring_process
    return if hiring_process.present?

    self.hiring_process = HiringProcess.default || HiringProcess.active.first
  end

  # PRIVATE METHOD: copy_from_template
  # PURPOSE: Copy content from position_template to posting
  # FIELDS: job_title, description, requirements
  # WHY: Templates provide base content, postings inherit but can customize
  # TRANSACTION: Runs before validation within same transaction
  def copy_from_template
    return unless position_template.present?
    return if job_title.present? # Don't overwrite if already set

    self.job_title = position_template.job_title
    self.description = position_template.description
    self.requirements = position_template.requirements
  end

  # PRIVATE METHOD: record_published_at
  # PURPOSE: Set published_at timestamp when first published
  # AASM CALLBACK: Triggered by publish! event
  # IDEMPOTENT: Only sets timestamp if nil (first publish)
  def record_published_at
    self.published_at ||= Time.current
    save
  end

  # PRIVATE METHOD: record_unpublished_at
  # PURPOSE: Set unpublished_at timestamp when unpublished
  # AASM CALLBACK: Triggered by unpublish! event
  def record_unpublished_at
    self.unpublished_at = Time.current
    save
  end

  # PRIVATE METHOD: has_hiring_process?
  # PURPOSE: Guard for publish! event
  # RETURNS: Boolean
  # WHY: Prevent publishing without hiring workflow
  def has_hiring_process?
    hiring_process.present?
  end

  # PRIVATE METHOD: invalidate_published_cache
  # PURPOSE: Clear Redis cache when status changes
  # CACHE KEY: Scoped by brand_id
  # TRIGGER: After commit when status changes
  def invalidate_published_cache
    Rails.cache.delete("job_postings/published/#{brand_id}")
  end
end
