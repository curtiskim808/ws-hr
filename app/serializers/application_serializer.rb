# ApplicationSerializer - JSON:API formatted serialization for applications
#
# T109: Implements JSON:API specification for job applications
# See: https://jsonapi.org/
#
# RESPONSE FORMAT:
# {
#   "data": {
#     "id": "1",
#     "type": "application",
#     "attributes": {
#       "status": "in_progress",
#       "status_label": "In Progress",
#       "applied_at": "2026-01-15T09:00:00Z",
#       "days_since_applied": 6,
#       "notes": "Strong candidate",
#       ...
#     },
#     "relationships": {
#       "applicant": { "data": { "id": "1", "type": "applicant" } },
#       "job_posting": { "data": { "id": "1", "type": "job_posting" } },
#       "current_stage": { "data": { "id": "2", "type": "hiring_stage" } },
#       "stage_transitions": { "data": [{ "id": "1", "type": "application_stage_transition" }] }
#     }
#   },
#   "included": [
#     { "id": "1", "type": "applicant", "attributes": { "full_name": "John Doe", ... } },
#     { "id": "1", "type": "job_posting", "attributes": { "job_title": "Backend Engineer", ... } },
#     { "id": "2", "type": "hiring_stage", "attributes": { "name": "Phone Screen", ... } }
#   ]
# }
#
# WHY JSON:API:
# - Standardized response format
# - Relationship handling for applicant, job_posting, stages
# - Consistent pagination, filtering, sorting
# - Client libraries available in all languages
class ApplicationSerializer
  include JSONAPI::Serializer

  # =============================================================================
  # ATTRIBUTES
  # =============================================================================

  # STATUS FIELDS
  # status: Current application state (in_progress, hired, rejected, archived)
  attributes :status

  # TIMESTAMPS
  # applied_at: When applicant submitted application
  # hired_at: When applicant was hired (null if not hired)
  # rejected_at: When applicant was rejected (null if not rejected)
  # archived_at: When application was archived (null if not archived)
  attributes :applied_at,
             :hired_at,
             :rejected_at,
             :archived_at

  # REJECTION DETAILS
  # rejection_reason: Why applicant was rejected (null if not rejected)
  attributes :rejection_reason

  # NOTES
  # notes: Internal notes about the application
  attributes :notes

  # STANDARD TIMESTAMPS
  attributes :created_at,
             :updated_at

  # =============================================================================
  # COMPUTED ATTRIBUTES
  # =============================================================================

  # COMPUTED: status_label
  # PURPOSE: Human-readable status
  # EXAMPLE: "in_progress" → "In Progress"
  attribute :status_label do |application|
    application.status.humanize
  end

  # COMPUTED: days_since_applied
  # PURPOSE: How many days since application was submitted
  # RETURNS: Integer
  # USE CASE: Display "Applied 5 days ago" in dashboard
  attribute :days_since_applied do |application|
    ((Time.current - application.applied_at) / 1.day).floor
  end

  # COMPUTED: current_stage_name
  # PURPOSE: Name of current hiring stage
  # RETURNS: String or null
  # EXAMPLE: "Phone Screen"
  attribute :current_stage_name do |application|
    application.current_stage&.name
  end

  # COMPUTED: applicant_name
  # PURPOSE: Full name of applicant
  # RETURNS: String
  # EXAMPLE: "John Doe"
  # WHY: Convenient for list views without including full applicant
  attribute :applicant_name do |application|
    application.applicant.full_name
  end

  # COMPUTED: job_title
  # PURPOSE: Title of the job they applied for
  # RETURNS: String
  # EXAMPLE: "Backend Engineer"
  # WHY: Convenient for list views without including full job_posting
  attribute :job_title do |application|
    application.job_posting.job_title
  end

  # COMPUTED: hired_by_name
  # PURPOSE: Name of user who hired the applicant
  # RETURNS: String or null
  # EXAMPLE: "Sarah Johnson"
  attribute :hired_by_name do |application|
    application.hired_by&.full_name
  end

  # COMPUTED: rejected_by_name
  # PURPOSE: Name of user who rejected the applicant
  # RETURNS: String or null
  # EXAMPLE: "Mike Wilson"
  attribute :rejected_by_name do |application|
    application.rejected_by&.full_name
  end

  # COMPUTED: stage_transitions_count
  # PURPOSE: Number of stage transitions
  # RETURNS: Integer
  # WHY: Helps UI show application activity without loading transitions
  attribute :stage_transitions_count do |application|
    application.stage_transitions.count
  end

  # =============================================================================
  # RELATIONSHIPS
  # =============================================================================

  # RELATIONSHIP: applicant
  # PURPOSE: The person who applied
  # INCLUDE: Pass include: [:applicant] to include full data
  belongs_to :applicant, serializer: ApplicantSerializer

  # RELATIONSHIP: job_posting
  # PURPOSE: The job they applied for
  # INCLUDE: Pass include: [:job_posting] to include full data
  belongs_to :job_posting, serializer: JobPostingSerializer

  # RELATIONSHIP: current_stage
  # PURPOSE: Current stage in hiring process
  # INCLUDE: Pass include: [:current_stage] to include full data
  belongs_to :current_stage, serializer: HiringStageSerializer

  # RELATIONSHIP: hiring_process
  # PURPOSE: The hiring process workflow
  # INCLUDE: Pass include: [:hiring_process] to include full data
  belongs_to :hiring_process

  # RELATIONSHIP: hired_by
  # PURPOSE: User who made hiring decision
  # INCLUDE: Pass include: [:hired_by] to include full data
  belongs_to :hired_by, serializer: UserSerializer

  # RELATIONSHIP: rejected_by
  # PURPOSE: User who made rejection decision
  # INCLUDE: Pass include: [:rejected_by] to include full data
  belongs_to :rejected_by, serializer: UserSerializer

  # RELATIONSHIP: stage_transitions
  # PURPOSE: Audit trail of stage changes
  # INCLUDE: Pass include: [:stage_transitions] to include full data
  has_many :stage_transitions, serializer: ApplicationStageTransitionSerializer
end
