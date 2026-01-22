# LocationSerializer - JSON:API formatted serialization for locations
# Serialize location data for API responses

class LocationSerializer
  include JSONAPI::Serializer

  attributes :name,
             :address,
             :city,
             :state,
             :postal_code,
             :country,
             :timezone

  attribute :full_address do |location|
    location.full_address
  end
end
