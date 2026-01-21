# UserSerializer - JSON:API formatted serialization for users
#
# PURPOSE: Serialize user data for API responses (limited fields for security)
# WHY: Used when including users in other responses (transitioned_by, hired_by, etc.)
#
# SECURITY: Only exposes safe, non-sensitive fields
# NOTE: Email is NOT exposed by default for privacy
#
# RESPONSE FORMAT:
# {
#   "data": {
#     "id": "1",
#     "type": "user",
#     "attributes": {
#       "full_name": "Sarah Johnson",
#       "first_name": "Sarah",
#       "last_name": "Johnson",
#       "role": "hiring_manager"
#     }
#   }
# }
class UserSerializer
  include JSONAPI::Serializer

  # ATTRIBUTES
  # Expose only safe, non-sensitive fields
  attributes :first_name,
             :last_name,
             :role

  # COMPUTED: full_name
  # PURPOSE: Combined first and last name
  # EXAMPLE: "Sarah Johnson"
  attribute :full_name do |user|
    user.full_name
  end

  # COMPUTED: role_label
  # PURPOSE: Human-readable role
  # EXAMPLE: "hiring_manager" → "Hiring Manager"
  attribute :role_label do |user|
    user.role.humanize
  end
end
