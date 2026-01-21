# HiringStageSerializer - JSON:API formatted serialization for hiring stages
#
# PURPOSE: Serialize hiring stage data for API responses
# WHY: Used when including current_stage in application responses
#
# RESPONSE FORMAT:
# {
#   "data": {
#     "id": "1",
#     "type": "hiring_stage",
#     "attributes": {
#       "name": "Phone Screen",
#       "stage_type": "interview",
#       "position": 2,
#       "required": true
#     }
#   }
# }
class HiringStageSerializer
  include JSONAPI::Serializer

  # ATTRIBUTES
  attributes :name,
             :stage_type,
             :position,
             :required,
             :settings,
             :created_at,
             :updated_at

  # COMPUTED: stage_type_label
  # PURPOSE: Human-readable stage type
  # EXAMPLE: "interview" → "Interview"
  attribute :stage_type_label do |stage|
    stage.stage_type.humanize
  end

  # RELATIONSHIP: hiring_process
  belongs_to :hiring_process
end
