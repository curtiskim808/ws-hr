# CreateHiringStages Migration - T052
#
# PURPOSE: Create hiring_stages table to define steps in a hiring process
# WHY: Each hiring process consists of multiple stages (Application, Interview, Offer, etc.)
# BUSINESS LOGIC:
#   - Stages are ordered by position (1, 2, 3, ...)
#   - Each stage has a type: application, interview, or decision
#   - Stages can be required or optional
#   - Settings (JSONB) stores stage-specific configuration
#
# EXAMPLE DATA:
#   Standard Hiring Process:
#   1. Application (type: application, position: 1, required: true)
#   2. Phone Screen (type: interview, position: 2, required: true)
#   3. Technical Interview (type: interview, position: 3, required: true)
#   4. Final Decision (type: decision, position: 4, required: true)
#
# RELATIONSHIP: Many hiring_stages belong to one hiring_process
class CreateHiringStages < ActiveRecord::Migration[8.0]
  def change
    create_table :hiring_stages do |t|
      # PARENT RELATIONSHIP: Belongs to hiring_process
      # REQUIRED: Every stage is part of exactly one hiring process
      # CASCADE DELETE: When process is deleted, all its stages are deleted
      # INDEX: Part of composite index for ordering stages
      t.references :hiring_process, null: false, foreign_key: true, index: true

      # STAGE IDENTIFICATION
      # name: Human-readable stage name (e.g., "Phone Screen", "Technical Interview")
      # REQUIRED: Displayed in UI and application timeline
      # EXAMPLES: "Application Review", "HR Interview", "Background Check", "Offer"
      t.string :name, null: false

      # STAGE TYPE
      # stage_type: Categorizes stage by function
      # ENUM VALUES (defined in model):
      #   - application (0): Initial submission stage
      #   - interview (1): Interview/assessment stages
      #   - decision (2): Final decision/offer stage
      # REQUIRED: Used for workflow logic and UI grouping
      # DEFAULT: application (first stage is usually application)
      t.integer :stage_type, null: false, default: 0

      # STAGE ORDERING
      # position: Defines order of stages in the process
      # REQUIRED: Stages execute in order (1, 2, 3, ...)
      # UNIQUE: Within a hiring_process, each position must be unique
      # INDEX: Part of composite index for sorting stages
      t.integer :position, null: false

      # STAGE REQUIREMENT
      # required: Whether this stage must be completed
      # BUSINESS RULE: Applications cannot skip required stages
      # OPTIONAL STAGES: Can be bypassed in certain scenarios
      # DEFAULT: true (most stages are required)
      # EXAMPLE: "Technical Assessment" might be optional for senior roles
      t.boolean :required, default: true, null: false

      # STAGE CONFIGURATION
      # settings: JSONB column for stage-specific configuration
      # FLEXIBLE: Different stage types may need different settings
      # EXAMPLES:
      #   Interview stage: { "duration_minutes": 60, "interviewers_required": 2 }
      #   Application stage: { "auto_advance": true, "review_deadline_days": 3 }
      #   Decision stage: { "approval_required": true, "approver_role": "hiring_manager" }
      # DEFAULT: {} (empty hash)
      t.jsonb :settings, default: {}, null: false

      # TIMESTAMPS
      # created_at: When stage was created
      # updated_at: When stage was last modified
      t.timestamps
    end

    # COMPOSITE INDEX: hiring_process_id + position
    # PURPOSE: Fast lookup and ordering of stages within a process
    # QUERY: SELECT * FROM hiring_stages WHERE hiring_process_id = ? ORDER BY position
    # UNIQUENESS: Ensure no duplicate positions within a process
    # PERFORMANCE: O(log n) lookup, prevents duplicate positions
    add_index :hiring_stages, [ :hiring_process_id, :position ],
              unique: true,
              name: 'index_hiring_stages_on_process_and_position'
  end
end
