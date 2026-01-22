# HiringProcessSerializer - JSON:API formatted serialization for hiring processes
# Serialize hiring process for API responses

class HiringProcessSerializer
  include JSONAPI::Serializer

  attributes :name,
             :is_default,
             :active,
             :created_at,
             :updated_at

  attribute :stage_count do |process|
    process.stage_count
  end

  attribute :stage_names do |process|
    process.stage_names
  end

  belongs_to :brand
  has_many :hiring_stages, serializer: HiringStageSerializer
end
