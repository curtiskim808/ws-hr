# HiringStage Model - T057
#
# PURPOSE: Define individual steps within a hiring process
# WHY: Hiring processes consist of ordered stages (Application, Interview, Offer, etc.)
# BUSINESS LOGIC:
#   - Stages are ordered by position (1, 2, 3, ...)
#   - Each stage has a type: application, interview, or decision
#   - Stages can be required or optional
#   - Settings (JSONB) stores stage-specific configuration
#
# EXAMPLE STAGES:
#   Position 1: "Application Review" (type: application, required: true)
#   Position 2: "Phone Screen" (type: interview, required: true)
#   Position 3: "Technical Interview" (type: interview, required: true)
#   Position 4: "Final Decision" (type: decision, required: true)
#
# RELATIONSHIP: Many stages belong to one hiring_process
# ORDERING: Stages must have unique positions within their process
class HiringStage < ApplicationRecord
  # =============================================================================
  # ASSOCIATIONS
  # =============================================================================

  # PARENT: HiringProcess
  # REQUIREMENT: Every stage belongs to exactly one hiring process
  # VALIDATION: Presence enforced by database (null: false)
  # CASCADE: Stage is deleted when process is deleted
  belongs_to :hiring_process

  # USAGE: Applications
  # PURPOSE: Applications currently at this stage
  # RELATIONSHIP: has_many applications via current_stage_id
  # NOTE: This association will be defined when Application model is created (T089)
  # has_many :current_applications, class_name: 'Application', foreign_key: 'current_stage_id'

  # =============================================================================
  # ENUMS
  # =============================================================================

  # ENUM: stage_type
  # PURPOSE: Categorize stages by their function in the hiring process
  # VALUES:
  #   - application (0): Initial submission and review stages
  #   - interview (1): Interview and assessment stages
  #   - decision (2): Final decision, offer, and onboarding stages
  #
  # EXAMPLES:
  #   Application stages: "Application Review", "Resume Screening"
  #   Interview stages: "Phone Screen", "Technical Interview", "Panel Interview"
  #   Decision stages: "Hiring Decision", "Offer", "Background Check"
  #
  # WHY ENUM:
  #   - UI can group stages by type
  #   - Different types may have different workflows
  #   - Interview stages require scheduling, decision stages don't
  #
  # RAILS 8 SYNTAX: enum :attribute, {...}, prefix: true
  # PREFIX: Generates methods like stage_type_application?, stage_type_interview?, stage_type_decision?
  enum :stage_type, {
    application: 0,
    interview: 1,
    decision: 2
  }, prefix: true

  # =============================================================================
  # VALIDATIONS
  # =============================================================================

  # REQUIRED FIELDS
  # name: Human-readable stage name (e.g., "Phone Screen")
  # REASON: Displayed in UI and application timeline
  validates :name, presence: true

  # position: Order of stage in the process
  # REASON: Defines workflow sequence
  validates :position, presence: true

  # stage_type: Category of stage (application, interview, decision)
  # REASON: Used for workflow logic and UI grouping
  validates :stage_type, presence: true

  # UNIQUENESS: Position must be unique within hiring_process
  # BUSINESS RULE: Can't have two stages at position 2 in same process
  # SCOPE: Within hiring_process (each process has own sequence)
  # DATABASE: Enforced by unique composite index (hiring_process_id, position)
  validates :position, uniqueness: { scope: :hiring_process_id, message: "must be unique within hiring process" }

  # NUMERICALITY: Position must be positive integer
  # BUSINESS RULE: Positions start at 1, not 0
  # REASON: More intuitive for users (Stage 1, 2, 3, not 0, 1, 2)
  validates :position, numericality: { only_integer: true, greater_than: 0 }

  # =============================================================================
  # SCOPES
  # =============================================================================

  # SCOPE: ordered
  # PURPOSE: Get stages in correct order (by position)
  # DEFAULT: Already defined in HiringProcess association
  # QUERY: SELECT * FROM hiring_stages ORDER BY position ASC
  # USE CASE: Display stages in sequence
  scope :ordered, -> { order(position: :asc) }

  # SCOPE: by_type
  # PURPOSE: Filter stages by type (application, interview, or decision)
  # QUERY: SELECT * FROM hiring_stages WHERE stage_type = ?
  # USE CASE: Show only interview stages for scheduling
  #
  # EXAMPLE:
  #   HiringStage.by_type(:interview)
  #   => [#<HiringStage name: "Phone Screen">, #<HiringStage name: "Technical Interview">]
  scope :by_type, ->(type) { where(stage_type: type) }

  # SCOPE: required_stages
  # PURPOSE: Get only required stages
  # QUERY: SELECT * FROM hiring_stages WHERE required = true
  # USE CASE: Validate application has completed all required stages
  #
  # EXAMPLE:
  #   process.hiring_stages.required_stages
  #   => [#<HiringStage name: "Application Review">, #<HiringStage name: "Phone Screen">]
  scope :required_stages, -> { where(required: true) }

  # =============================================================================
  # BUSINESS LOGIC METHODS
  # =============================================================================

  # METHOD: next_stage
  # PURPOSE: Get the next stage in the hiring process
  # RETURNS: HiringStage with position = self.position + 1, or nil if this is the last stage
  # USE CASE: Advance application to next stage
  #
  # EXAMPLE:
  #   current_stage = HiringStage.find_by(position: 2)
  #   current_stage.next_stage
  #   => #<HiringStage id: 3, name: "Technical Interview", position: 3>
  def next_stage
    hiring_process.hiring_stages.find_by(position: position + 1)
  end

  # METHOD: previous_stage
  # PURPOSE: Get the previous stage in the hiring process
  # RETURNS: HiringStage with position = self.position - 1, or nil if this is the first stage
  # USE CASE: Allow moving application backwards in special cases
  #
  # EXAMPLE:
  #   current_stage = HiringStage.find_by(position: 3)
  #   current_stage.previous_stage
  #   => #<HiringStage id: 2, name: "Phone Screen", position: 2>
  def previous_stage
    return nil if position <= 1
    hiring_process.hiring_stages.find_by(position: position - 1)
  end

  # METHOD: first_stage?
  # PURPOSE: Check if this is the first stage in the process
  # RETURNS: Boolean
  # USE CASE: Applications start at first stage, cannot go backwards
  #
  # EXAMPLE:
  #   stage.first_stage?
  #   => true
  def first_stage?
    position == 1
  end

  # METHOD: last_stage?
  # PURPOSE: Check if this is the final stage in the process
  # RETURNS: Boolean
  # USE CASE: Completing last stage may trigger hire/reject decision
  #
  # EXAMPLE:
  #   stage.last_stage?
  #   => true
  def last_stage?
    position == hiring_process.stage_count
  end

  # METHOD: interview_stage?
  # PURPOSE: Check if this is an interview stage
  # RETURNS: Boolean
  # USE CASE: Interview stages require scheduling
  # SHORTHAND: Uses enum-generated method stage_type_interview?
  alias_method :interview_stage?, :stage_type_interview?

  # METHOD: setting
  # PURPOSE: Get a specific setting value with default
  # PARAMETERS:
  #   - key: Setting key (string or symbol)
  #   - default: Default value if setting not found
  # RETURNS: Setting value or default
  # USE CASE: Retrieve stage-specific configuration
  #
  # EXAMPLE:
  #   stage.setting('duration_minutes', 60)
  #   => 60
  #
  #   stage.settings = { 'duration_minutes' => 30 }
  #   stage.setting('duration_minutes', 60)
  #   => 30
  def setting(key, default = nil)
    settings.fetch(key.to_s, default)
  end
end
