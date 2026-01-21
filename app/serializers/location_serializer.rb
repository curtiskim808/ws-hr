# LocationSerializer - JSON:API formatted serialization for locations
#
# PURPOSE: Serialize location data for API responses
# WHY: Used when including locations in job posting responses
#
# RESPONSE FORMAT:
# {
#   "data": {
#     "id": "1",
#     "type": "location",
#     "attributes": {
#       "name": "San Francisco HQ",
#       "address": "123 Market St",
#       "city": "San Francisco",
#       "state": "CA",
#       "postal_code": "94105",
#       "country": "USA",
#       "timezone": "America/Los_Angeles",
#       "full_address": "123 Market St, San Francisco, CA, 94105, USA"
#     }
#   }
# }
class LocationSerializer
  include JSONAPI::Serializer

  # ATTRIBUTES
  attributes :name,
             :address,
             :city,
             :state,
             :postal_code,
             :country,
             :timezone

  # COMPUTED: full_address
  # PURPOSE: Complete formatted address
  # EXAMPLE: "123 Market St, San Francisco, CA, 94105, USA"
  attribute :full_address do |location|
    location.full_address
  end
end
