module BrandScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :brand
    validates :brand_id, presence: true

    # Default scope - all queries automatically scoped to current brand
    default_scope { where(brand_id: Current.brand&.id) if Current.brand }

    # Explicit scope for cases where default_scope is bypassed
    scope :for_brand, ->(brand) { where(brand_id: brand.is_a?(Brand) ? brand.id : brand) }
  end

  class_methods do
    # Use this to bypass brand scoping when needed (e.g., rake tasks, background jobs)
    def unscoped_by_brand
      unscoped
    end
  end
end
