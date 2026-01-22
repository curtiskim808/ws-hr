# Applicant Model
# Represent individuals who apply for jobs

class Applicant < ApplicationRecord
  # MULTI-TENANT SCOPING
  # Automatically scope all queries by Current.brand
  include BrandScoped


  # PARENT: Brand
  # REQUIREMENT: Every applicant belongs to exactly one brand
  belongs_to :brand

  has_many :applications, dependent: :destroy

  has_one_attached :resume


  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true

  validates :email, format: {
    with: URI::MailTo::EMAIL_REGEXP,
    message: "must be a valid email address"
  }

  # EMAIL UNIQUENESS VALIDATION (within brand)
  validates :email, uniqueness: {
    scope: :brand_id,
    message: "has already applied (duplicate applicant in this brand)"
  }

  validates :phone, format: {
    with: /\A[\d\s\-\(\)\+\.]+\z/,
    message: "must be a valid phone number"
  }, allow_blank: true

  validate :resume_validation, if: -> { resume.attached? }


  def full_name
    "#{first_name} #{last_name}"
  end


  scope :recent, -> { order(created_at: :desc) }

  scope :flagged, -> { where(flagged: true) }

  scope :by_source, ->(source) { where(source: source) }


  private

  def resume_validation
    return unless resume.attached?

    unless resume.content_type.in?(%w[application/pdf application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document])
      errors.add(:resume, "must be a PDF, DOC, or DOCX file")
    end

    if resume.byte_size > 5.megabytes
      errors.add(:resume, "must be less than 5MB")
    end
  end
end
