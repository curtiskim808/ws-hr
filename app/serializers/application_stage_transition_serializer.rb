# ApplicationStageTransitionSerializer - JSON:API formatted serialization
# Serialize stage transition records for audit trail

class ApplicationStageTransitionSerializer
  include JSONAPI::Serializer

  attributes :transitioned_at,
             :notes,
             :created_at

  attribute :stage_change_summary do |transition|
    transition.stage_change_summary
  end

  attribute :from_stage_name do |transition|
    transition.from_stage&.name
  end

  attribute :to_stage_name do |transition|
    transition.to_stage.name
  end

  attribute :transitioned_by_name do |transition|
    transition.transitioned_by&.full_name
  end

  belongs_to :from_stage, serializer: HiringStageSerializer
  belongs_to :to_stage, serializer: HiringStageSerializer
  belongs_to :transitioned_by, serializer: UserSerializer
end
