class Brand < ApplicationRecord
  has_many :locations, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :position_templates, dependent: :destroy
  has_many :job_postings, dependent: :destroy

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: { case_sensitive: false }
  validates :subdomain, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "must be lowercase alphanumeric with hyphens" }

  before_validation :normalize_subdomain

  private
    def normalize_subdomain
      self.subdomain = subdomain.to_s.downcase.strip if subdomain.present?
    end
end
