# Application Model - T089-T096, T123-T127
#
# PURPOSE: Represent a job application (applicant applying to a job posting)
# WHY: Track application lifecycle from submission to hire/reject decision
# BUSINESS LOGIC:
#   - One applicant can have multiple applications (to different jobs)
#   - Application follows hiring_process stages
#   - Has status: in_progress, hired, rejected, archived
#   - Fat model methods for business logic (hire!, reject!, advance_to_stage!)
#
# STATE MACHINE (AASM):
#   in_progress (default) → hire! → hired
#                        → reject! → rejected
#                        → archive! → archived
#
# NOTIFICATIONS (T123-T127):
#   - after_commit :publish_received_notification (on create)
#   - after_commit :publish_hired_notification (when status → hired)
#   - after_commit :publish_rejected_notification (when status → rejected)
#   - after_commit :publish_stage_changed_notification (when current_stage_id changes)
#
# EXAMPLE SCENARIOS:
#   1. John Doe applies for "Backend Engineer" (status: in_progress)
#   2. Recruiter advances John to "Phone Screen" stage
#   3. Recruiter advances John to "Technical Interview" stage
#   4. Hiring manager calls hire!(user) → status: hired, hired_at: Time.current
#
# MULTI-TENANT: Automatic brand scoping via BrandScoped concern
class Application < ApplicationRecord
  # MULTI-TENANT SCOPING
  # PURPOSE: Automatically scope all queries by Current.brand
  # RESULT: Users only see applications from their brand
  # IMPLEMENTATION: Adds default_scope and sets brand_id on create
  include BrandScoped

  # STATE MACHINE
  # PURPOSE: Manage application lifecycle with explicit state transitions
  # WHY: Prevent invalid state changes, track lifecycle events
  # LIBRARY: AASM (Acts As State Machine) gem
  include AASM

  # =============================================================================
  # T089: ASSOCIATIONS
  # =============================================================================

  # PARENT: Brand
  # REQUIREMENT: Every application belongs to exactly one brand
  # VALIDATION: Presence enforced by database (null: false)
  belongs_to :brand

  # APPLICANT: Who is applying?
  # REQUIREMENT: Every application must have an applicant
  # RELATIONSHIP: Many applications can belong to one applicant
  belongs_to :applicant

  # JOB POSTING: What job are they applying for?
  # REQUIREMENT: Every application is for a specific job posting
  # RELATIONSHIP: Many applications can be for one job posting
  belongs_to :job_posting

  # HIRING PROCESS: What workflow does this application follow?
  # REQUIREMENT: Copied from job_posting.hiring_process at creation
  # IMMUTABLE: Once set, hiring_process doesn't change
  belongs_to :hiring_process

  # CURRENT STAGE: What stage is the applicant at?
  # OPTIONAL: Can be null initially (before review starts)
  # RELATIONSHIP: belongs_to a HiringStage
  # BUSINESS RULE: current_stage must belong to this application's hiring_process
  belongs_to :current_stage, class_name: 'HiringStage', optional: true

  # HIRED BY: Which user made the hiring decision?
  # OPTIONAL: Only set when application is hired
  # RELATIONSHIP: belongs_to a User
  belongs_to :hired_by, class_name: 'User', optional: true

  # REJECTED BY: Which user made the rejection decision?
  # OPTIONAL: Only set when application is rejected
  # RELATIONSHIP: belongs_to a User
  belongs_to :rejected_by, class_name: 'User', optional: true

  # =============================================================================
  # T100: STAGE TRANSITIONS ASSOCIATION
  # =============================================================================

  # STAGE TRANSITIONS: Audit trail of stage changes
  # PURPOSE: Track complete history of application progression through hiring stages
  # RELATIONSHIP: has_many ApplicationStageTransition records
  # CASCADE: When application is deleted, all stage transitions are deleted
  # ORDER: Chronological (oldest first) by default
  # USE CASE: View candidate's complete journey through hiring process
  #
  # EXAMPLE:
  #   application.stage_transitions
  #   => [
  #     #<ApplicationStageTransition from: nil, to: "Application Review", transitioned_at: ...>,
  #     #<ApplicationStageTransition from: "Application Review", to: "Phone Screen", transitioned_at: ...>,
  #     #<ApplicationStageTransition from: "Phone Screen", to: "Interview", transitioned_at: ...>
  #   ]
  has_many :stage_transitions,
           class_name: 'ApplicationStageTransition',
           dependent: :destroy,
           inverse_of: :application

  # =============================================================================
  # ENUM: Status
  # =============================================================================
  # PURPOSE: Define status enum values for AASM
  # WHY: AASM with enum: true requires explicit enum definition in Rails 8
  # VALUES: in_progress (0), hired (1), rejected (2), archived (3)
  enum :status, { in_progress: 0, hired: 1, rejected: 2, archived: 3 }, prefix: false

  # =============================================================================
  # T090: AASM STATE MACHINE
  # =============================================================================
  # PURPOSE: Manage application lifecycle with state transitions
  # STATES:
  #   - in_progress: Application being reviewed/processed
  #   - hired: Applicant was hired
  #   - rejected: Applicant was rejected
  #   - archived: Application archived (no longer active)
  #
  # TRANSITIONS:
  #   in_progress → hired (hire!)
  #   in_progress → rejected (reject!)
  #   in_progress → archived (archive!)
  #
  # WHY STATE MACHINE:
  #   - Explicit state transitions prevent invalid states
  #   - Callbacks automatically update timestamps
  #   - Guards prevent invalid transitions
  #   - Auditable state changes

  aasm column: :status, enum: true do
    # STATE: in_progress
    # INITIAL STATE: All new applications start in progress
    # VISIBLE: To hiring team for review
    # NEXT STATES: hired, rejected, archived
    state :in_progress, initial: true

    # STATE: hired
    # VISIBLE: Archived as successful hire
    # TERMINAL: No further transitions
    state :hired

    # STATE: rejected
    # VISIBLE: Archived as rejection
    # TERMINAL: No further transitions
    state :rejected

    # STATE: archived
    # VISIBLE: Archived for record keeping
    # TERMINAL: No further transitions
    state :archived

    # =============================================================================
    # T091: AASM EVENTS (STATE TRANSITIONS)
    # =============================================================================

    # EVENT: hire
    # PURPOSE: Hire the applicant
    # FROM STATES: in_progress
    # TO STATE: hired
    # CALLBACK: Sets hired_at timestamp
    # GUARD: Must be called via hire!(user) method which sets hired_by
    # GUARD: T157 - Cannot hire from rejected status
    #
    # EXAMPLE:
    #   application.hire!(current_user)
    #   application.status          # => "hired"
    #   application.hired_at        # => 2026-01-21 10:30:00 UTC
    #   application.hired_by        # => #<User id: 1>
    event :hire, after: :record_hired_at do
      transitions from: :in_progress, to: :hired, guard: :can_hire?
    end

    # EVENT: reject
    # PURPOSE: Reject the applicant
    # FROM STATES: in_progress
    # TO STATE: rejected
    # CALLBACK: Sets rejected_at timestamp
    # GUARD: Must be called via reject!(reason, user) method
    # GUARD: T158 - Cannot reject from hired status
    #
    # EXAMPLE:
    #   application.reject!("Not enough experience", current_user)
    #   application.status          # => "rejected"
    #   application.rejected_at     # => 2026-01-21 10:30:00 UTC
    #   application.rejection_reason # => "Not enough experience"
    event :reject, after: :record_rejected_at do
      transitions from: :in_progress, to: :rejected, guard: :can_reject?
    end

    # EVENT: archive
    # PURPOSE: Archive the application
    # FROM STATES: in_progress, hired, rejected
    # TO STATE: archived
    # CALLBACK: Sets archived_at timestamp
    #
    # EXAMPLE:
    #   application.archive!
    #   application.status     # => "archived"
    #   application.archived_at # => 2026-01-21 10:30:00 UTC
    event :archive, after: :record_archived_at do
      transitions from: [:in_progress, :hired, :rejected], to: :archived
    end
  end

  # =============================================================================
  # T094: VALIDATIONS
  # =============================================================================

  # DUPLICATE PREVENTION
  # PURPOSE: Prevent same applicant from applying twice to same job
  # BUSINESS RULE: One applicant can only apply once per job posting
  # DATABASE: Enforced by unique composite index (applicant_id, job_posting_id)
  #
  # EXAMPLE:
  #   John Doe → "Backend Engineer" (allowed)
  #   John Doe → "Backend Engineer" (rejected - duplicate)
  #   John Doe → "Frontend Engineer" (allowed - different job)
  validates :applicant_id, uniqueness: {
    scope: :job_posting_id,
    message: 'has already applied to this job posting'
  }

  # APPLIED_AT VALIDATION
  # PURPOSE: Ensure applied_at is always set
  # BUSINESS RULE: Cannot create application without applied_at
  validates :applied_at, presence: true

  # =============================================================================
  # T092: FAT MODEL METHODS (BUSINESS LOGIC)
  # =============================================================================

  # METHOD: hire!(user)
  # PURPOSE: Hire this applicant (business logic wrapper for AASM event)
  # PARAMETERS:
  #   - user: User making the hiring decision
  # IMPLEMENTATION:
  #   - Set hired_by = user
  #   - Call AASM hire event (sets hired_at, changes status to 'hired')
  #   - Wrap in transaction for atomicity
  # RAISES: AASM::InvalidTransition if already hired/rejected
  #
  # EXAMPLE:
  #   application.hire!(current_user)
  #   application.hired?          # => true
  #   application.hired_by        # => #<User id: 1>
  #   application.hired_at        # => 2026-01-21 10:30:00 UTC
  #
  # WHY FAT MODEL:
  #   - Encapsulates business logic in model
  #   - Ensures hired_by is always set when hiring
  #   - Transaction ensures atomicity
  #   - Controller just calls this method (thin controller)
  def hire!(user)
    transaction do
      self.hired_by = user
      aasm.fire(:hire) # Call AASM event (not self.hire! which would be recursive)
      save!
    end
  end

  # METHOD: reject!(reason, user)
  # PURPOSE: Reject this applicant (business logic wrapper for AASM event)
  # PARAMETERS:
  #   - reason: Why was the applicant rejected?
  #   - user: User making the rejection decision
  # IMPLEMENTATION:
  #   - Set rejection_reason = reason
  #   - Set rejected_by = user
  #   - Call AASM reject event (sets rejected_at, changes status to 'rejected')
  #   - Wrap in transaction for atomicity
  # RAISES: AASM::InvalidTransition if already hired/rejected
  #
  # EXAMPLE:
  #   application.reject!("Not enough experience", current_user)
  #   application.rejected?       # => true
  #   application.rejection_reason # => "Not enough experience"
  #   application.rejected_by     # => #<User id: 1>
  #
  # WHY FAT MODEL:
  #   - Encapsulates business logic in model
  #   - Ensures rejection_reason and rejected_by are always set
  #   - Transaction ensures atomicity
  def reject!(reason, user)
    transaction do
      self.rejection_reason = reason
      self.rejected_by = user
      aasm.fire(:reject) # Call AASM event (not self.reject! which would be recursive)
      save!
    end
  end

  # METHOD: advance_to_stage!(stage, user, notes)
  # PURPOSE: Advance application to the next hiring stage
  # PARAMETERS:
  #   - stage: HiringStage to advance to
  #   - user: User making the decision (optional, for audit trail)
  #   - notes: Optional notes about why this transition happened
  # IMPLEMENTATION:
  #   - Validate stage belongs to this application's hiring_process
  #   - Create ApplicationStageTransition record for audit trail (T101)
  #   - Update current_stage
  #   - Save record
  #   - Wrap in transaction for atomicity
  # RAISES: ArgumentError if stage doesn't belong to hiring_process
  #
  # EXAMPLE:
  #   application.current_stage # => #<HiringStage id: 1, name: "Application Review">
  #   phone_screen = hiring_process.hiring_stages.find_by(position: 2)
  #   application.advance_to_stage!(phone_screen, current_user, "Strong technical background")
  #   application.current_stage # => #<HiringStage id: 2, name: "Phone Screen">
  #   application.stage_transitions.last.notes # => "Strong technical background"
  #
  # WHY FAT MODEL:
  #   - Encapsulates stage advancement logic
  #   - Validates stage belongs to hiring_process
  #   - Creates audit trail (ApplicationStageTransition)
  #   - Transaction ensures atomicity
  #   - Triggers stage change notification (T104)
  def advance_to_stage!(stage, user = nil, notes = nil)
    # Validate stage belongs to this application's hiring_process
    unless stage.hiring_process_id == hiring_process_id
      raise ArgumentError, "Stage must belong to this application's hiring process"
    end

    transaction do
      # T101: Create ApplicationStageTransition record for audit trail
      # BEFORE updating current_stage so we capture the from_stage
      from_stage = current_stage

      # Create transition record
      stage_transitions.create!(
        from_stage: from_stage,
        to_stage: stage,
        transitioned_by: user,
        transitioned_at: Time.current,
        notes: notes
      )

      # Update current_stage
      self.current_stage = stage
      save!
    end
  end

  # =============================================================================
  # T093: SCOPES
  # =============================================================================

  # SCOPE: with_applicant
  # PURPOSE: Eager load applicant association
  # QUERY: SELECT * FROM applications ... INNER JOIN applicants ...
  # USE CASE: Avoid N+1 queries when displaying applicant names
  # PERFORMANCE: One query instead of N+1
  #
  # EXAMPLE:
  #   Application.with_applicant.each do |app|
  #     puts app.applicant.full_name  # No extra query
  #   end
  scope :with_applicant, -> { includes(:applicant) }

  # SCOPE: with_job_posting
  # PURPOSE: Eager load job_posting association
  # QUERY: SELECT * FROM applications ... INNER JOIN job_postings ...
  # USE CASE: Avoid N+1 queries when displaying job titles
  #
  # EXAMPLE:
  #   Application.with_job_posting.each do |app|
  #     puts app.job_posting.job_title  # No extra query
  #   end
  scope :with_job_posting, -> { includes(:job_posting) }

  # SCOPE: recent
  # PURPOSE: Get applications ordered by most recent first
  # QUERY: SELECT * FROM applications WHERE brand_id = ? ORDER BY created_at DESC
  # USE CASE: Dashboard showing recent applications
  # PERFORMANCE: Uses composite index (brand_id, created_at)
  #
  # EXAMPLE:
  #   Application.recent.limit(10)
  #   => [#<Application id: 3>, #<Application id: 2>, #<Application id: 1>]
  scope :recent, -> { order(created_at: :desc) }

  # SCOPE: for_location
  # PURPOSE: Filter applications by location (via job_posting)
  # QUERY: SELECT * FROM applications INNER JOIN job_postings ON ... WHERE job_postings.location_id = ?
  # USE CASE: View all applications for SF HQ jobs
  # PARAMETER: location_id - integer
  #
  # EXAMPLE:
  #   Application.for_location(1)  # All applications for location_id: 1
  #   => [#<Application id: 1>, #<Application id: 2>]
  scope :for_location, ->(location_id) {
    joins(:job_posting).where(job_postings: { location_id: location_id })
  }

  # SCOPE: by_status
  # PURPOSE: Filter applications by status
  # QUERY: SELECT * FROM applications WHERE brand_id = ? AND status = ?
  # USE CASE: View all in-progress applications
  # PARAMETER: status - symbol or string (e.g., :in_progress, 'hired')
  #
  # EXAMPLE:
  #   Application.by_status(:in_progress)
  #   => [#<Application id: 1, status: 'in_progress'>, ...]
  #
  #   Application.by_status('hired').count
  #   => 5
  scope :by_status, ->(status) { where(status: status) }

  # =============================================================================
  # T103: STAGE TRANSITIONS SCOPE
  # =============================================================================

  # SCOPE: with_transitions
  # PURPOSE: Eager load stage_transitions with associated stages and user
  # QUERY: Includes stage_transitions, from_stage, to_stage, transitioned_by
  # USE CASE: Avoid N+1 queries when displaying application timeline
  # PERFORMANCE: Single query instead of N+1 for transitions, stages, users
  #
  # EXAMPLE:
  #   Application.with_transitions.each do |app|
  #     app.stage_transitions.each do |t|
  #       puts "#{t.from_stage&.name} → #{t.to_stage.name} by #{t.transitioned_by&.full_name}"
  #       # No extra queries - all data already loaded
  #     end
  #   end
  #
  # WHY NESTED INCLUDES:
  #   - stage_transitions: Load all transition records
  #   - from_stage: Load the "from" stage for each transition
  #   - to_stage: Load the "to" stage for each transition
  #   - transitioned_by: Load the user who made the transition
  scope :with_transitions, -> {
    includes(stage_transitions: [:from_stage, :to_stage, :transitioned_by])
  }

  # =============================================================================
  # T096: CLASS METHOD - FACTORY PATTERN
  # =============================================================================

  # CLASS METHOD: create_from_form!(params)
  # PURPOSE: Create application from public form submission
  # PARAMETERS:
  #   - params: Hash with applicant and application data
  # IMPLEMENTATION:
  #   - Find or create applicant by email
  #   - Create application for applicant
  #   - Set applied_at to Time.current
  #   - Set hiring_process from job_posting
  #   - Set current_stage to first stage
  #   - Wrap in transaction for atomicity
  # RETURNS: Application object
  # RAISES: ActiveRecord::RecordInvalid if validation fails
  #
  # EXAMPLE PARAMS:
  #   {
  #     job_posting_id: 1,
  #     applicant: {
  #       first_name: "John",
  #       last_name: "Doe",
  #       email: "john@example.com",
  #       phone: "555-0100",
  #       source: "linkedin"
  #     },
  #     notes: "Interested in remote work"
  #   }
  #
  # EXAMPLE USAGE:
  #   application = Application.create_from_form!(params)
  #   application.applicant.full_name  # => "John Doe"
  #   application.job_posting         # => #<JobPosting id: 1>
  #   application.current_stage.name   # => "Application Review"
  #
  # WHY CLASS METHOD:
  #   - Encapsulates complex creation logic
  #   - Finds or creates applicant (prevents duplicates)
  #   - Sets up hiring_process and first stage automatically
  #   - Transaction ensures atomicity
  #   - Public API for application submissions
  def self.create_from_form!(params)
    transaction do
      # Find or create applicant by email
      applicant_params = params[:applicant] || params['applicant']
      applicant = Applicant.find_or_create_by!(
        brand_id: Current.brand.id,
        email: applicant_params[:email] || applicant_params['email']
      ) do |a|
        a.first_name = applicant_params[:first_name] || applicant_params['first_name']
        a.last_name = applicant_params[:last_name] || applicant_params['last_name']
        a.phone = applicant_params[:phone] || applicant_params['phone']
        a.source = applicant_params[:source] || applicant_params['source']
        a.preferred_language = applicant_params[:preferred_language] || applicant_params['preferred_language'] || 'en'
      end

      # Find job posting
      job_posting = JobPosting.find(params[:job_posting_id] || params['job_posting_id'])

      # Create application
      application = create!(
        brand_id: Current.brand.id,
        applicant: applicant,
        job_posting: job_posting,
        hiring_process: job_posting.hiring_process,
        current_stage: job_posting.hiring_process.first_stage,
        applied_at: Time.current,
        notes: params[:notes] || params['notes']
      )

      application
    end
  end

  # =============================================================================
  # T095, T123-T127: CALLBACKS - NOTIFICATIONS
  # =============================================================================
  # CRITICAL: ALL notification callbacks use after_commit to ensure:
  #   1. Transaction is complete before notification
  #   2. Rollbacks don't trigger phantom notifications
  #   3. Follows DHH/37signals pattern for side effects

  # CALLBACK: publish_received_notification (T123)
  # PURPOSE: Publish notification when new application is received
  # TRIGGER: after_commit on create
  # ACTION: Enqueue NotificationJob with :application_received event
  # USE CASE: Notify hiring manager about new applicant
  after_commit :publish_received_notification, on: :create

  # CALLBACK: publish_hired_notification (T124)
  # PURPOSE: Publish notification when applicant is hired
  # TRIGGER: after_commit when status changes to 'hired'
  # ACTION: Enqueue NotificationJob with :candidate_hired event
  # USE CASE: Send congratulations email to applicant
  after_commit :publish_hired_notification, if: :saved_change_to_hired_status?

  # CALLBACK: publish_rejected_notification (T125)
  # PURPOSE: Publish notification when applicant is rejected
  # TRIGGER: after_commit when status changes to 'rejected'
  # ACTION: Enqueue NotificationJob with :candidate_rejected event
  # USE CASE: Send polite rejection email to applicant
  after_commit :publish_rejected_notification, if: :saved_change_to_rejected_status?

  # CALLBACK: publish_stage_changed_notification (T126)
  # PURPOSE: Publish notification when application moves to a new stage
  # TRIGGER: after_commit when current_stage_id changes
  # ACTION: Enqueue NotificationJob with :stage_changed event
  # USE CASE: Notify hiring team when candidate advances
  after_commit :publish_stage_changed_notification, if: :saved_change_to_current_stage_id?

  # =============================================================================
  # T157-T158: AASM GUARD METHODS
  # =============================================================================

  # METHOD: can_hire?
  # PURPOSE: Guard method for AASM hire event
  # T157: Prevent hiring from rejected status
  # RETURNS: true if application is in_progress, false if rejected or hired
  # USE CASE: AASM guard to prevent invalid state transitions
  #
  # EXAMPLE:
  #   application.status = 'in_progress'
  #   application.can_hire?  # => true
  #
  #   application.status = 'rejected'
  #   application.can_hire?  # => false
  def can_hire?
    in_progress?
  end

  # METHOD: can_reject?
  # PURPOSE: Guard method for AASM reject event
  # T158: Prevent rejecting from hired status
  # RETURNS: true if application is in_progress, false if hired or rejected
  # USE CASE: AASM guard to prevent invalid state transitions
  #
  # EXAMPLE:
  #   application.status = 'in_progress'
  #   application.can_reject?  # => true
  #
  #   application.status = 'hired'
  #   application.can_reject?  # => false
  def can_reject?
    in_progress?
  end

  # =============================================================================
  # PRIVATE METHODS - AASM CALLBACKS
  # =============================================================================

  private

  # PRIVATE METHOD: record_hired_at
  # PURPOSE: Set hired_at timestamp when application is hired
  # TRIGGER: after AASM hire event
  # IMPLEMENTATION: Set hired_at to Time.current
  def record_hired_at
    update_column(:hired_at, Time.current)
  end

  # PRIVATE METHOD: record_rejected_at
  # PURPOSE: Set rejected_at timestamp when application is rejected
  # TRIGGER: after AASM reject event
  # IMPLEMENTATION: Set rejected_at to Time.current
  def record_rejected_at
    update_column(:rejected_at, Time.current)
  end

  # PRIVATE METHOD: record_archived_at
  # PURPOSE: Set archived_at timestamp when application is archived
  # TRIGGER: after AASM archive event
  # IMPLEMENTATION: Set archived_at to Time.current
  def record_archived_at
    update_column(:archived_at, Time.current)
  end

  # =============================================================================
  # T127: PRIVATE METHODS - NOTIFICATION ENQUEUING
  # =============================================================================
  # T136: GRACEFUL ERROR HANDLING
  # All notification callbacks log errors but don't raise exceptions
  # WHY: Notification failures should never block business operations

  # PRIVATE METHOD: publish_received_notification (T123)
  # PURPOSE: Enqueue notification for new application
  # IMPLEMENTATION: Enqueue NotificationJob with :application_received
  # ERROR HANDLING: Log errors, don't raise (graceful degradation)
  def publish_received_notification
    Rails.logger.info "[Application] Publishing :application_received notification for ##{id}"
    NotificationJob.perform_later(:application_received, id)
  rescue StandardError => e
    Rails.logger.error "[Application] Failed to enqueue :application_received notification: #{e.message}"
    # Don't re-raise - notification failure should not affect application creation
  end

  # PRIVATE METHOD: publish_hired_notification (T124)
  # PURPOSE: Enqueue notification when applicant is hired
  # IMPLEMENTATION: Enqueue NotificationJob with :candidate_hired
  # ERROR HANDLING: Log errors, don't raise (graceful degradation)
  def publish_hired_notification
    Rails.logger.info "[Application] Publishing :candidate_hired notification for ##{id}"
    NotificationJob.perform_later(:candidate_hired, id)
  rescue StandardError => e
    Rails.logger.error "[Application] Failed to enqueue :candidate_hired notification: #{e.message}"
    # Don't re-raise - notification failure should not affect hiring
  end

  # PRIVATE METHOD: publish_rejected_notification (T125)
  # PURPOSE: Enqueue notification when applicant is rejected
  # IMPLEMENTATION: Enqueue NotificationJob with :candidate_rejected
  # ERROR HANDLING: Log errors, don't raise (graceful degradation)
  def publish_rejected_notification
    Rails.logger.info "[Application] Publishing :candidate_rejected notification for ##{id}"
    NotificationJob.perform_later(:candidate_rejected, id)
  rescue StandardError => e
    Rails.logger.error "[Application] Failed to enqueue :candidate_rejected notification: #{e.message}"
    # Don't re-raise - notification failure should not affect rejection
  end

  # PRIVATE METHOD: publish_stage_changed_notification (T126)
  # PURPOSE: Enqueue notification when application moves to new stage
  # IMPLEMENTATION: Enqueue NotificationJob with :stage_changed
  # ERROR HANDLING: Log errors, don't raise (graceful degradation)
  def publish_stage_changed_notification
    Rails.logger.info "[Application] Publishing :stage_changed notification for ##{id} to stage: #{current_stage&.name}"
    NotificationJob.perform_later(:stage_changed, id)
  rescue StandardError => e
    Rails.logger.error "[Application] Failed to enqueue :stage_changed notification: #{e.message}"
    # Don't re-raise - notification failure should not affect stage change
  end

  # =============================================================================
  # PRIVATE HELPER METHODS - STATUS CHANGE DETECTION
  # =============================================================================

  # PRIVATE METHOD: saved_change_to_hired_status?
  # PURPOSE: Detect if status just changed to 'hired'
  # RETURNS: Boolean true if previous_changes includes status → 'hired'
  # USE CASE: Conditional for publish_hired_notification callback
  def saved_change_to_hired_status?
    saved_change_to_status? && status == 'hired'
  end

  # PRIVATE METHOD: saved_change_to_rejected_status?
  # PURPOSE: Detect if status just changed to 'rejected'
  # RETURNS: Boolean true if previous_changes includes status → 'rejected'
  # USE CASE: Conditional for publish_rejected_notification callback
  def saved_change_to_rejected_status?
    saved_change_to_status? && status == 'rejected'
  end
end
