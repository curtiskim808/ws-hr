# UserSerializer - JSON:API formatted serialization for users
# Serialize user data for API responses (limited fields for security)

class UserSerializer
  include JSONAPI::Serializer

  attributes :first_name,
             :last_name,
             :role

  attribute :full_name do |user|
    user.full_name
  end

  attribute :role_label do |user|
    user.role.humanize
  end
end
