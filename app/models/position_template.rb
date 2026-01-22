class PositionTemplate < ApplicationRecord
  # MULTI-TENANT SCOPING
  # Include BrandScoped concern to automatically scope all queries to Current.brand
  include BrandScoped

  belongs_to :brand
  has_many :job_postings, dependent: :restrict_with_error

  attribute :status, :integer, default: 0
  enum :status, {
    draft: 0,
    active: 1
  }, prefix: true

  after_commit :invalidate_active_cache

  validates :name, presence: true
  validates :job_title, presence: true
  validates :category, presence: true
  validates :department, presence: true


  scope :active, -> { where(status: :active) }

  scope :by_category, ->(category) { where(category: category) }

  scope :recent, -> { order(created_at: :desc) }

  scope :active_cached, -> {
    Rails.cache.fetch("position_templates/active/#{Current.brand&.id}", expires_in: 1.hour) do
      active.to_a
    end
  }

  private

  def invalidate_active_cache
    Rails.cache.delete("position_templates/active/#{brand_id}")
  end
end
