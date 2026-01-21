# CreateApplicationStageTransitions Migration - T097, T098
#
# PURPOSE: Track audit trail of application stage changes
# WHY: When applications move between hiring stages, we need to record:
#   - Which stages they moved from/to
#   - Who made the transition
#   - When it happened
#   - Any notes about the transition
#
# BUSINESS LOGIC:
#   - Each time Application#advance_to_stage! is called, create a transition record
#   - Provides complete audit trail for compliance and analytics
#   - Helps hiring managers see full candidate journey
#
# EXAMPLE DATA:
#   - John Doe's application moved from "Phone Screen" → "Onsite Interview" by Sarah (hiring_manager)
#   - Jane Smith's application moved from "Application Review" → "Phone Screen" by Admin
#   - Bob Jones stuck at "Phone Screen" for 14 days (can identify with analytics)
#
# MULTI-TENANT: Not needed - transitions are tied to applications which are already brand-scoped
class CreateApplicationStageTransitions < ActiveRecord::Migration[8.0]
  def change
    create_table :application_stage_transitions do |t|
      # =============================================================================
      # CORE ASSOCIATIONS
      # =============================================================================

      # APPLICATION: Which application is this transition for?
      # REQUIRED: Every transition belongs to an application
      # RELATIONSHIP: belongs_to :application
      # CASCADE: When application is deleted, transitions are deleted
      # INDEX: Part of composite index (application_id, transitioned_at)
      t.references :application, null: false, foreign_key: true, index: true

      # FROM STAGE: What stage did the application transition FROM?
      # NULLABLE: First transition (initial stage assignment) has no "from"
      # RELATIONSHIP: belongs_to :from_stage, class_name: 'HiringStage'
      # EXAMPLE: "Phone Screen"
      t.references :from_stage, foreign_key: { to_table: :hiring_stages }, index: true

      # TO STAGE: What stage did the application transition TO?
      # REQUIRED: Every transition must have a destination stage
      # RELATIONSHIP: belongs_to :to_stage, class_name: 'HiringStage'
      # EXAMPLE: "Onsite Interview"
      t.references :to_stage, null: false, foreign_key: { to_table: :hiring_stages }, index: true

      # TRANSITIONED BY: Which user made this transition?
      # NULLABLE: Can be null for automated transitions
      # RELATIONSHIP: belongs_to :transitioned_by, class_name: 'User'
      # USE CASE: Audit trail - who moved this application forward
      # EXAMPLE: Sarah (hiring_manager) advanced candidate to next stage
      t.references :transitioned_by, foreign_key: { to_table: :users }, index: true

      # =============================================================================
      # AUDIT TRAIL DATA
      # =============================================================================

      # TRANSITIONED AT: When did this transition happen?
      # REQUIRED: Timestamp of the transition
      # DEFAULT: Set to Time.current when transition is created
      # USE CASE: Analytics - time spent in each stage
      # EXAMPLE: Moved from "Phone Screen" → "Interview" on 2026-01-15 14:30:00
      t.datetime :transitioned_at, null: false

      # NOTES: Optional notes about why this transition happened
      # OPTIONAL: Free-form text for context
      # EXAMPLE: "Candidate showed strong technical skills in phone screen"
      # USE CASE: Context for future reviewers
      t.text :notes

      # =============================================================================
      # TIMESTAMPS
      # =============================================================================

      # STANDARD RAILS TIMESTAMPS
      # created_at: When transition record was created (should match transitioned_at)
      # updated_at: When transition record was last modified (rarely changes)
      t.timestamps
    end

    # =============================================================================
    # T098: COMPOSITE INDEXES
    # =============================================================================

    # COMPOSITE INDEX: application_id + transitioned_at
    # PURPOSE: Fast lookup of transitions for an application in chronological order
    # QUERY: SELECT * FROM application_stage_transitions WHERE application_id = ? ORDER BY transitioned_at
    # USE CASE: Show candidate's stage progression timeline
    # PERFORMANCE: O(log n) sorted retrieval
    add_index :application_stage_transitions, [:application_id, :transitioned_at],
              name: 'index_app_stage_transitions_on_app_and_time'
  end
end
