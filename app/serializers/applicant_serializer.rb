# ApplicantSerializer - JSON:API formatted serialization for applicants
#
# T108: Implements JSON:API specification for applicants
# See: https://jsonapi.org/
#
# RESPONSE FORMAT:
# {
#   "data": {
#     "id": "1",
#     "type": "applicant",
#     "attributes": {
#       "first_name": "John",
#       "last_name": "Doe",
#       "full_name": "John Doe",
#       "email": "john@example.com",
#       "phone": "555-0100",
#       "source": "linkedin",
#       "applications_count": 2,
#       ...
#     },
#     "relationships": {
#       "applications": {
#         "data": [{ "id": "1", "type": "application" }]
#       }
#     }
#   }
# }
#
# WHY JSON:API:
# - Standardized response format
# - Consistent pagination, filtering, sorting
# - Relationship handling for applications
# - Client libraries available in all languages
class ApplicantSerializer
  include JSONAPI::Serializer

  # ATTRIBUTES
  # All fields exposed to the API
  attributes :first_name,
             :last_name,
             :email,
             :phone,
             :preferred_language,
             :source,
             :flagged,
             :flag_reason,
             :created_at,
             :updated_at

  # COMPUTED ATTRIBUTES

  # Full name - combines first and last name
  # EXAMPLE: "John Doe"
  attribute :full_name do |applicant|
    applicant.full_name
  end

  # Applications count - number of applications submitted
  # EXAMPLE: 2
  # WHY: Helps UI show applicant activity without loading full applications
  attribute :applications_count do |applicant|
    applicant.applications.count
  end

  # Resume attached - boolean indicating if resume is attached
  # EXAMPLE: true
  # WHY: Helps UI show resume indicator without fetching attachment
  attribute :resume_attached do |applicant|
    applicant.resume.attached?
  end

  # RELATIONSHIPS

  # Applications - list of applications submitted by this applicant
  # INCLUDE: Pass include: [:applications] to serializer to include
  has_many :applications, serializer: ApplicationSerializer
end
