# ApplicationStageTransitionSerializer - JSON:API formatted serialization
#
# PURPOSE: Serialize stage transition records for audit trail
# WHY: Used when including stage_transitions in application responses
#
# RESPONSE FORMAT:
# {
#   "data": {
#     "id": "1",
#     "type": "application_stage_transition",
#     "attributes": {
#       "transitioned_at": "2026-01-20T14:30:00Z",
#       "stage_change_summary": "Phone Screen → Interview",
#       "notes": "Passed phone screen with flying colors"
#     },
#     "relationships": {
#       "from_stage": { "data": { "id": "1", "type": "hiring_stage" } },
#       "to_stage": { "data": { "id": "2", "type": "hiring_stage" } },
#       "transitioned_by": { "data": { "id": "1", "type": "user" } }
#     }
#   }
# }
class ApplicationStageTransitionSerializer
  include JSONAPI::Serializer

  # ATTRIBUTES
  attributes :transitioned_at,
             :notes,
             :created_at

  # COMPUTED: stage_change_summary
  # PURPOSE: Human-readable transition description
  # EXAMPLE: "Phone Screen → Interview" or "Applied → Application Review"
  attribute :stage_change_summary do |transition|
    transition.stage_change_summary
  end

  # COMPUTED: from_stage_name
  # PURPOSE: Name of the stage transitioned from
  # EXAMPLE: "Phone Screen" or nil for initial transition
  attribute :from_stage_name do |transition|
    transition.from_stage&.name
  end

  # COMPUTED: to_stage_name
  # PURPOSE: Name of the stage transitioned to
  # EXAMPLE: "Interview"
  attribute :to_stage_name do |transition|
    transition.to_stage.name
  end

  # COMPUTED: transitioned_by_name
  # PURPOSE: Name of user who made the transition
  # EXAMPLE: "Sarah Johnson" or nil for automated transitions
  attribute :transitioned_by_name do |transition|
    transition.transitioned_by&.full_name
  end

  # RELATIONSHIPS
  belongs_to :from_stage, serializer: HiringStageSerializer
  belongs_to :to_stage, serializer: HiringStageSerializer
  belongs_to :transitioned_by, serializer: UserSerializer
end
