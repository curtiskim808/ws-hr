# JobPosting Model
# Represent published job listings on the careers page

class JobPosting < ApplicationRecord
  # MULTI-TENANT SCOPING
  # Automatically scope all queries by Current.brand
  include BrandScoped

  include AASM


  # PARENT: Brand
  # REQUIREMENT: Every job posting belongs to exactly one brand
  belongs_to :brand

  belongs_to :position_template

  belongs_to :location

  belongs_to :hiring_process

  has_many :applications, dependent: :restrict_with_error

  attribute :status, :integer, default: 0
  enum :status, { draft: 0, published: 1, link_only: 2, unpublished: 3 }, prefix: false


  aasm column: :status, enum: true do
    state :draft, initial: true

    state :published

    state :link_only

    state :unpublished


    event :publish, after: :record_published_at do
      transitions from: [ :draft, :link_only ], to: :published,
                  guard: :has_hiring_process?
    end

    event :unpublish, after: :record_unpublished_at do
      transitions from: [ :published, :link_only ], to: :unpublished
    end

    event :make_link_only do
      transitions from: :published, to: :link_only
    end
  end


  validates :job_title, presence: true

  validates :hiring_process, presence: { message: "must be set before publishing" },
                            if: :published?


  scope :published, -> { where(status: :published) }

  scope :at_location, ->(location_id) { where(location_id: location_id) }

  scope :recent, -> { order(published_at: :desc) }

  scope :published_cached, -> {
    Rails.cache.fetch("job_postings/published/#{Current.brand&.id}", expires_in: 1.hour) do
      published.to_a
    end
  }


  before_validation :set_default_hiring_process, on: :create

  before_validation :copy_from_template, on: :create

  after_commit :invalidate_published_cache, if: :saved_change_to_status?


  def days_since_published
    return nil unless published_at
    ((Time.current - published_at) / 1.day).floor
  end

  def accepting_applications?
    published? || link_only?
  end

  # Check if posting appears on public careers page
  def visible_on_careers_page?
    published?
  end

  private

  def set_default_hiring_process
    return if hiring_process.present?

    self.hiring_process = HiringProcess.where(brand_id: brand_id).default ||
                          HiringProcess.where(brand_id: brand_id).active.first
  end

  def copy_from_template
    return unless position_template.present?
    return if job_title.present? # Don't overwrite if already set

    self.job_title = position_template.job_title
    self.description = position_template.description
    self.requirements = position_template.requirements
  end

  def record_published_at
    self.published_at ||= Time.current
    save
  end

  def record_unpublished_at
    self.unpublished_at = Time.current
    save
  end

  def has_hiring_process?
    hiring_process.present?
  end

  def invalidate_published_cache
    Rails.cache.delete("job_postings/published/#{brand_id}")
  end
end
