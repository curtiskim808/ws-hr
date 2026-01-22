# HiringStage Model
# Define individual steps within a hiring process

class HiringStage < ApplicationRecord

  belongs_to :hiring_process



  enum :stage_type, {
    application: 0,
    interview: 1,
    decision: 2
  }, prefix: true


  validates :name, presence: true

  validates :position, presence: true

  validates :stage_type, presence: true

  validates :position, uniqueness: { scope: :hiring_process_id, message: "must be unique within hiring process" }

  validates :position, numericality: { only_integer: true, greater_than: 0 }


  scope :ordered, -> { order(position: :asc) }

  scope :by_type, ->(type) { where(stage_type: type) }

  scope :required_stages, -> { where(required: true) }


  def next_stage
    hiring_process.hiring_stages.find_by(position: position + 1)
  end

  def previous_stage
    return nil if position <= 1
    hiring_process.hiring_stages.find_by(position: position - 1)
  end

  def first_stage?
    position == 1
  end

  def last_stage?
    position == hiring_process.stage_count
  end

  alias_method :interview_stage?, :stage_type_interview?

  def setting(key, default = nil)
    settings.fetch(key.to_s, default)
  end
end
