class LocationAssignment < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :location

  # Validations
  validates :user_id, uniqueness: { scope: :location_id }
end