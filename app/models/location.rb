class Location < ApplicationRecord
  belongs_to :brand
  has_many :location_assignments, dependent: :destroy
  has_many :users, through: :location_assignments
  has_many :job_postings, dependent: :destroy

  validates :name, presence: true
  validates :timezone, presence: true
  validates :brand_id, presence: true

  # Default scope to ensure brand isolation (will be overridden by BrandScoped concern)
  scope :for_brand, ->(brand) { where(brand_id: brand.id) }

  def full_address
    [address, city, state, postal_code, country].compact.join(", ")
  end
end
