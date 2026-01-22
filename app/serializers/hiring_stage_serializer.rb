# HiringStageSerializer - JSON:API formatted serialization for hiring stages
# Serialize hiring stage data for API responses

class HiringStageSerializer
  include JSONAPI::Serializer

  attributes :name,
             :stage_type,
             :position,
             :required,
             :settings,
             :created_at,
             :updated_at

  attribute :stage_type_label do |stage|
    stage.stage_type.humanize
  end

  belongs_to :hiring_process
end
