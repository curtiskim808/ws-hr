# ApplicationStageTransition Model - T099, T102
#
# PURPOSE: Track audit trail of application stage changes
# WHY: Provides complete history of candidate's progression through hiring process
# BUSINESS LOGIC:
#   - Created automatically when Application#advance_to_stage! is called
#   - Immutable once created (never updated, only created)
#   - Provides analytics: time spent in each stage, bottlenecks
#
# EXAMPLE SCENARIOS:
#   1. John Doe's application moves from "Phone Screen" → "Onsite Interview"
#      - Create transition record with from_stage_id, to_stage_id, transitioned_by, transitioned_at
#   2. Hiring manager views candidate timeline
#      - Fetch all transitions ordered by transitioned_at
#   3. Analytics: Average time in "Phone Screen" stage
#      - Calculate duration between transitions
#
# NOT MULTI-TENANT SCOPED: Transitions belong to applications which are already brand-scoped
class ApplicationStageTransition < ApplicationRecord
  # =============================================================================
  # T099: ASSOCIATIONS
  # =============================================================================

  # PARENT: Application
  # REQUIREMENT: Every transition belongs to exactly one application
  # VALIDATION: Presence enforced by database (null: false)
  belongs_to :application

  # FROM STAGE: What stage did the application come from?
  # OPTIONAL: Can be nil for initial stage assignment
  # CLASS_NAME: HiringStage (not ApplicationStage)
  belongs_to :from_stage, class_name: 'HiringStage', optional: true

  # TO STAGE: What stage did the application move to?
  # REQUIRED: Every transition must have a destination
  # CLASS_NAME: HiringStage
  belongs_to :to_stage, class_name: 'HiringStage'

  # TRANSITIONED BY: Which user made this transition?
  # OPTIONAL: Can be nil for automated/system transitions
  # CLASS_NAME: User
  belongs_to :transitioned_by, class_name: 'User', optional: true

  # =============================================================================
  # T099: VALIDATIONS
  # =============================================================================

  # REQUIRED FIELDS
  # application: Must belong to an application
  # to_stage: Must have a destination stage
  # transitioned_at: Must have a timestamp
  validates :application, presence: true
  validates :to_stage, presence: true
  validates :transitioned_at, presence: true

  # BUSINESS RULE VALIDATION: to_stage must belong to application's hiring_process
  # PURPOSE: Prevent invalid stage transitions (e.g., assigning stage from wrong hiring process)
  # EXAMPLE: If application uses "Standard Process", can't assign stage from "Executive Process"
  validate :to_stage_must_belong_to_hiring_process

  # BUSINESS RULE VALIDATION: from_stage must belong to application's hiring_process (if present)
  # PURPOSE: Ensure audit trail integrity
  validate :from_stage_must_belong_to_hiring_process, if: -> { from_stage.present? }

  # =============================================================================
  # T099: CALLBACKS
  # =============================================================================

  # DEFAULT: Set transitioned_at to current time if not provided
  # WHY: Ensure every transition has a timestamp
  # WHEN: Before validation (so validation passes)
  before_validation :set_default_transitioned_at, on: :create

  # =============================================================================
  # T102: SCOPES
  # =============================================================================

  # SCOPE: chronological
  # PURPOSE: Get transitions ordered by time (oldest first)
  # QUERY: SELECT * FROM application_stage_transitions ORDER BY transitioned_at ASC
  # USE CASE: Show candidate's progression timeline from start to finish
  # PERFORMANCE: Uses composite index (application_id, transitioned_at)
  #
  # EXAMPLE:
  #   application.stage_transitions.chronological
  #   => [#<Transition "Applied" → "Phone Screen">, #<Transition "Phone Screen" → "Interview">]
  scope :chronological, -> { order(transitioned_at: :asc) }

  # SCOPE: reverse_chronological
  # PURPOSE: Get transitions ordered by time (newest first)
  # QUERY: SELECT * FROM application_stage_transitions ORDER BY transitioned_at DESC
  # USE CASE: Show most recent stage changes first
  #
  # EXAMPLE:
  #   application.stage_transitions.reverse_chronological.limit(5)
  #   => [#<Transition "Interview" → "Offer">, #<Transition "Phone Screen" → "Interview">]
  scope :reverse_chronological, -> { order(transitioned_at: :desc) }

  # SCOPE: with_user
  # PURPOSE: Eager load the user who made the transition
  # QUERY: Includes transitioned_by association
  # USE CASE: Avoid N+1 queries when displaying transition history
  # PERFORMANCE: Single query instead of N+1
  #
  # EXAMPLE:
  #   application.stage_transitions.with_user.each do |t|
  #     puts "#{t.transitioned_by.full_name} moved to #{t.to_stage.name}"
  #   end
  scope :with_user, -> { includes(:transitioned_by) }

  # SCOPE: with_stages
  # PURPOSE: Eager load both from_stage and to_stage
  # QUERY: Includes from_stage and to_stage associations
  # USE CASE: Avoid N+1 queries when displaying full transition details
  #
  # EXAMPLE:
  #   application.stage_transitions.with_stages.each do |t|
  #     puts "#{t.from_stage&.name} → #{t.to_stage.name}"
  #   end
  scope :with_stages, -> { includes(:from_stage, :to_stage) }

  # =============================================================================
  # T099: HELPER METHODS
  # =============================================================================

  # METHOD: duration_from_previous
  # PURPOSE: Calculate time spent in the "from_stage"
  # RETURNS: Integer (seconds) or nil if no previous transition
  # USE CASE: Analytics - how long did candidate spend in each stage
  #
  # ALGORITHM:
  #   1. Find the previous transition (where to_stage = this.from_stage)
  #   2. Calculate difference between this.transitioned_at and previous.transitioned_at
  #
  # EXAMPLE:
  #   transition = ApplicationStageTransition.find(123)
  #   transition.from_stage.name # => "Phone Screen"
  #   transition.to_stage.name   # => "Onsite Interview"
  #   transition.duration_from_previous # => 604800 (7 days in seconds)
  def duration_from_previous
    return nil unless from_stage.present?

    previous_transition = application.stage_transitions
                                     .where(to_stage_id: from_stage_id)
                                     .order(transitioned_at: :desc)
                                     .first

    return nil unless previous_transition

    (transitioned_at - previous_transition.transitioned_at).to_i
  end

  # METHOD: stage_change_summary
  # PURPOSE: Human-readable summary of the transition
  # RETURNS: String
  # USE CASE: Display in UI, notifications, logs
  #
  # EXAMPLE:
  #   transition.stage_change_summary
  #   => "Phone Screen → Onsite Interview"
  #
  #   initial_transition.stage_change_summary
  #   => "Applied → Application Review"
  def stage_change_summary
    if from_stage.present?
      "#{from_stage.name} → #{to_stage.name}"
    else
      "Applied → #{to_stage.name}"
    end
  end

  # =============================================================================
  # PRIVATE METHODS
  # =============================================================================

  private

  # PRIVATE METHOD: set_default_transitioned_at
  # PURPOSE: Set transitioned_at to current time if not provided
  # WHEN: Before validation on create
  def set_default_transitioned_at
    self.transitioned_at ||= Time.current
  end

  # PRIVATE VALIDATION: to_stage_must_belong_to_hiring_process
  # PURPOSE: Ensure to_stage belongs to application's hiring_process
  # ERRORS: Adds validation error if stage doesn't match hiring process
  def to_stage_must_belong_to_hiring_process
    return unless application && to_stage

    unless to_stage.hiring_process_id == application.hiring_process_id
      errors.add(:to_stage, "must belong to the application's hiring process")
    end
  end

  # PRIVATE VALIDATION: from_stage_must_belong_to_hiring_process
  # PURPOSE: Ensure from_stage belongs to application's hiring_process (if present)
  # ERRORS: Adds validation error if stage doesn't match hiring process
  def from_stage_must_belong_to_hiring_process
    return unless application && from_stage

    unless from_stage.hiring_process_id == application.hiring_process_id
      errors.add(:from_stage, "must belong to the application's hiring process")
    end
  end
end
