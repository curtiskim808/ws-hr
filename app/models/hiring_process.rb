# HiringProcess Model
# Define the hiring workflow stages for job postings

class HiringProcess < ApplicationRecord
  # MULTI-TENANT SCOPING
  # Automatically scope all queries by Current.brand
  include BrandScoped


  # PARENT: Brand
  # REQUIREMENT: Every hiring process belongs to exactly one brand
  belongs_to :brand

  has_many :hiring_stages, -> { order(position: :asc) }, dependent: :destroy, inverse_of: :hiring_process

  has_many :job_postings, dependent: :restrict_with_error

  has_many :applications, dependent: :restrict_with_error


  validates :name, presence: true

  # UNIQUENESS: One default process per brand
  # BUSINESS RULE: Only one process can be marked is_default per brand
  validates :is_default, uniqueness: { scope: :brand_id, message: "only one default process allowed per brand" },
                         if: :is_default?


  # Find the default hiring process for the current brand
  scope :default, -> { where(is_default: true).first }

  # Find all active hiring processes for the current brand
  scope :active, -> { where(active: true) }


  def first_stage
    hiring_stages.find_by(position: 1)
  end

  def stage_count
    hiring_stages.count
  end

  def stage_names
    hiring_stages.pluck(:name)
  end


  def next_stage(current_stage)
    return first_stage if current_stage.nil?

    unless current_stage.hiring_process_id == id
      raise ArgumentError, "Stage must belong to this hiring process"
    end

    hiring_stages.find_by(position: current_stage.position + 1)
  end


  before_validation :unset_other_defaults, if: :is_default?

  private

  # Ensure only one default process per brand
  def unset_other_defaults
    HiringProcess.where(brand_id: brand_id, is_default: true)
                 .where.not(id: id)
                 .update_all(is_default: false)
  end
end
