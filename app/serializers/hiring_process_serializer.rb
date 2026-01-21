# HiringProcessSerializer - JSON:API formatted serialization for hiring processes
#
# PURPOSE: Serialize hiring process for API responses
# See: https://jsonapi.org/
class HiringProcessSerializer
  include JSONAPI::Serializer

  # ATTRIBUTES
  attributes :name,
             :is_default,
             :active,
             :created_at,
             :updated_at

  # COMPUTED: stage_count
  # PURPOSE: Number of stages in this process
  attribute :stage_count do |process|
    process.stage_count
  end

  # COMPUTED: stage_names
  # PURPOSE: Ordered list of stage names
  attribute :stage_names do |process|
    process.stage_names
  end

  # RELATIONSHIP: hiring_stages
  belongs_to :brand
  has_many :hiring_stages, serializer: HiringStageSerializer
end
