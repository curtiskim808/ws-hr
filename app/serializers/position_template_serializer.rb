# PositionTemplateSerializer - JSON:API formatted serialization
#
# T042: Implements JSON:API specification for position templates
# See: https://jsonapi.org/
#
# RESPONSE FORMAT:
# {
#   "data": {
#     "id": "1",
#     "type": "position_template",
#     "attributes": {
#       "name": "Senior Software Engineer",
#       "job_title": "Senior Software Engineer - Backend",
#       "category": "Engineering",
#       ...
#     }
#   }
# }
#
# WHY JSON:API:
# - Standardized response format
# - Consistent pagination, filtering, sorting
# - Relationship handling (for future associations)
# - Client libraries available in all languages
class PositionTemplateSerializer
  include JSONAPI::Serializer

  # ATTRIBUTES
  # All fields exposed to the API
  attributes :name,
             :job_title,
             :category,
             :department,
             :description,
             :requirements,
             :location_type,
             :employment_type,
             :education_requirement,
             :status,
             :created_at,
             :updated_at

  # COMPUTED ATTRIBUTES
  # Custom attribute to show human-readable status
  attribute :status_label do |template|
    template.status.humanize
  end

  # RELATIONSHIPS
  # Future: Can add relationships here when needed
  # Example: belongs_to :brand
  # Example: has_many :job_postings
end
