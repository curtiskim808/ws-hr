# HiringProcess Model - T055
#
# PURPOSE: Define the hiring workflow stages for job postings
# WHY: Different roles/departments may require different hiring stages
# BUSINESS LOGIC:
#   - Each brand can have multiple hiring processes
#   - One process per brand is marked as default
#   - Processes contain ordered stages (via hiring_stages)
#   - Inactive processes are archived but remain for historical applications
#
# EXAMPLE SCENARIOS:
#   1. Standard Hiring (default for most roles):
#      Application → Phone Screen → Technical Interview → Offer
#
#   2. Executive Hiring (for senior leadership):
#      Application → Executive Interview → Board Interview → Background Check → Offer
#
#   3. Internship Hiring (for summer interns):
#      Application → Group Interview → Offer
#
# MULTI-TENANT: Automatic brand scoping via BrandScoped concern
# ASSOCIATIONS:
#   - belongs_to :brand (via BrandScoped)
#   - has_many :hiring_stages (ordered by position)
#   - has_many :job_postings (uses this process)
#   - has_many :applications (follow this process)
class HiringProcess < ApplicationRecord
  # MULTI-TENANT SCOPING
  # PURPOSE: Automatically scope all queries by Current.brand
  # RESULT: Users only see hiring processes from their brand
  # IMPLEMENTATION: Adds default_scope and sets brand_id on create
  include BrandScoped

  # =============================================================================
  # ASSOCIATIONS
  # =============================================================================

  # PARENT: Brand
  # REQUIREMENT: Every hiring process belongs to exactly one brand
  # VALIDATION: Presence enforced by database (null: false)
  belongs_to :brand

  # CHILDREN: HiringStages
  # PURPOSE: Define the ordered steps in this hiring process
  # CASCADE DELETE: When process is deleted, all stages are deleted
  # ORDERING: Stages are ordered by position (1, 2, 3, ...)
  # INVERSE: Each stage belongs_to one hiring_process
  has_many :hiring_stages, -> { order(position: :asc) }, dependent: :destroy, inverse_of: :hiring_process

  # USAGE: JobPostings
  # PURPOSE: Job postings that use this hiring process
  # RESTRICT DELETE: Cannot delete process if job postings exist
  # REASON: Prevents orphaning active job postings
  has_many :job_postings, dependent: :restrict_with_error

  # USAGE: Applications
  # PURPOSE: Applications following this hiring process
  # RESTRICT DELETE: Cannot delete process if applications exist
  # REASON: Preserves historical hiring data
  has_many :applications, dependent: :restrict_with_error

  # =============================================================================
  # VALIDATIONS
  # =============================================================================

  # REQUIRED FIELDS
  # name: Human-readable process name (e.g., "Standard Hiring")
  # REASON: Used in UI for selecting hiring process
  validates :name, presence: true

  # UNIQUENESS: One default process per brand
  # BUSINESS RULE: Only one process can be marked is_default per brand
  # SCOPE: Within brand (multi-tenant)
  # CONDITION: Only validate if is_default is true
  # EXAMPLE: Acme can have ONE default process, Globex can have a different ONE
  validates :is_default, uniqueness: { scope: :brand_id, message: 'only one default process allowed per brand' },
                         if: :is_default?

  # =============================================================================
  # SCOPES - T056
  # =============================================================================

  # SCOPE: default
  # PURPOSE: Find the default hiring process for the current brand
  # QUERY: SELECT * FROM hiring_processes WHERE brand_id = ? AND is_default = true LIMIT 1
  # USE CASE: Job postings use default process unless explicitly specified
  # PERFORMANCE: Uses composite index (brand_id, is_default)
  # RETURNS: Single HiringProcess or nil
  #
  # EXAMPLE:
  #   HiringProcess.default
  #   => #<HiringProcess id: 1, name: "Standard Hiring", is_default: true>
  scope :default, -> { where(is_default: true).first }

  # SCOPE: active
  # PURPOSE: Find all active hiring processes for the current brand
  # QUERY: SELECT * FROM hiring_processes WHERE brand_id = ? AND active = true
  # USE CASE: Dropdown list when creating job posting
  # PERFORMANCE: Uses composite index (brand_id, active)
  # RETURNS: ActiveRecord::Relation
  #
  # EXAMPLE:
  #   HiringProcess.active
  #   => [#<HiringProcess id: 1, name: "Standard Hiring">, #<HiringProcess id: 2, name: "Executive Hiring">]
  scope :active, -> { where(active: true) }

  # =============================================================================
  # BUSINESS LOGIC METHODS - T058
  # =============================================================================

  # METHOD: first_stage
  # PURPOSE: Get the first stage in this hiring process
  # RETURNS: HiringStage with position = 1, or nil if no stages exist
  # USE CASE: When application is created, it starts at first_stage
  # PERFORMANCE: Uses composite index (hiring_process_id, position)
  #
  # EXAMPLE:
  #   process = HiringProcess.find(1)
  #   process.first_stage
  #   => #<HiringStage id: 1, name: "Application Review", position: 1>
  #
  # BUSINESS RULE: Applications always start at position 1
  def first_stage
    hiring_stages.find_by(position: 1)
  end

  # METHOD: stage_count
  # PURPOSE: Get total number of stages in this process
  # RETURNS: Integer count of stages
  # USE CASE: Display progress (e.g., "Stage 2 of 4")
  # PERFORMANCE: Uses counter cache if implemented, otherwise COUNT query
  #
  # EXAMPLE:
  #   process.stage_count
  #   => 4
  def stage_count
    hiring_stages.count
  end

  # METHOD: stage_names
  # PURPOSE: Get ordered list of stage names
  # RETURNS: Array of stage names
  # USE CASE: Display hiring process overview in UI
  #
  # EXAMPLE:
  #   process.stage_names
  #   => ["Application Review", "Phone Screen", "Technical Interview", "Offer"]
  def stage_names
    hiring_stages.pluck(:name)
  end

  # =============================================================================
  # CALLBACKS
  # =============================================================================

  # CALLBACK: Ensure only one default process per brand
  # TRIGGER: Before validation
  # ACTION: If setting is_default = true, unset is_default on all other processes for this brand
  # REASON: Maintain business rule of exactly one default process
  #
  # EXAMPLE:
  #   process1 = HiringProcess.create(brand: acme, name: "Standard", is_default: true)
  #   process2 = HiringProcess.create(brand: acme, name: "Executive", is_default: true)
  #   # process1.is_default is now false, process2.is_default is true
  before_validation :unset_other_defaults, if: :is_default?

  private

  # PRIVATE METHOD: unset_other_defaults
  # PURPOSE: Ensure only one default process per brand
  # IMPLEMENTATION: Set is_default = false for all other processes in same brand
  # TRANSACTION: Runs within same transaction as save
  def unset_other_defaults
    HiringProcess.where(brand_id: brand_id, is_default: true)
                 .where.not(id: id)
                 .update_all(is_default: false)
  end
end
