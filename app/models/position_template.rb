class PositionTemplate < ApplicationRecord
  # MULTI-TENANT SCOPING
  # Include BrandScoped concern to automatically scope all queries to Current.brand
  # This ensures users only see templates from their own brand
  include BrandScoped

  # ASSOCIATIONS
  belongs_to :brand
  has_many :job_postings, dependent: :restrict_with_error

  # ENUMS
  # Status enum: draft (0), active (1)
  # T036: Templates start as drafts and can be activated for use
  enum :status, {
    draft: 0,
    active: 1
  }, prefix: true

  # CALLBACKS
  # T038: Cache invalidation on create, update, or destroy
  # WHY: When templates change, we need to invalidate the cached active_cached scope
  # IMPORTANT: Use after_commit (not after_save) to ensure transaction is complete
  after_commit :invalidate_active_cache

  # VALIDATIONS
  # Core fields required for a valid position template
  validates :name, presence: true
  validates :job_title, presence: true
  validates :category, presence: true
  validates :department, presence: true

  # SCOPES
  # T037: Query scopes for common filtering patterns

  # Active templates only (status = active)
  # Usage: PositionTemplate.active
  scope :active, -> { where(status: :active) }

  # Filter by category
  # Usage: PositionTemplate.by_category("Engineering")
  scope :by_category, ->(category) { where(category: category) }

  # Recent templates (most recently created first)
  # Usage: PositionTemplate.recent
  scope :recent, -> { order(created_at: :desc) }

  # Active templates with Redis caching
  # Usage: PositionTemplate.active_cached
  # This caches the query result in Redis for better performance
  scope :active_cached, -> {
    Rails.cache.fetch("position_templates/active/#{Current.brand&.id}", expires_in: 1.hour) do
      active.to_a
    end
  }

  private

  # CACHE INVALIDATION
  # Invalidates the active_cached scope when a template is created, updated, or destroyed
  # This ensures the cache always reflects the current state
  def invalidate_active_cache
    Rails.cache.delete("position_templates/active/#{brand_id}")
  end
end
