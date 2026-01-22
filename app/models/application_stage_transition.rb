# ApplicationStageTransition Model - ,
# Track audit trail of application stage changes

class ApplicationStageTransition < ApplicationRecord
  belongs_to :application

  belongs_to :from_stage, class_name: "HiringStage", optional: true

  belongs_to :to_stage, class_name: "HiringStage"

  belongs_to :transitioned_by, class_name: "User", optional: true


  validates :application, presence: true
  validates :to_stage, presence: true
  validates :transitioned_at, presence: true

  validate :to_stage_must_belong_to_hiring_process

  validate :from_stage_must_belong_to_hiring_process, if: -> { from_stage.present? }


  before_validation :set_default_transitioned_at, on: :create



  scope :chronological, -> { order(transitioned_at: :asc) }

  scope :reverse_chronological, -> { order(transitioned_at: :desc) }

  scope :with_user, -> { includes(:transitioned_by) }

  scope :with_stages, -> { includes(:from_stage, :to_stage) }


  def duration_from_previous
    return nil unless from_stage.present?

    previous_transition = application.stage_transitions
                                     .where(to_stage_id: from_stage_id)
                                     .order(transitioned_at: :desc)
                                     .first

    return nil unless previous_transition

    (transitioned_at - previous_transition.transitioned_at).to_i
  end

  def stage_change_summary
    if from_stage.present?
      "#{from_stage.name} → #{to_stage.name}"
    else
      "Applied → #{to_stage.name}"
    end
  end


  private

  def set_default_transitioned_at
    self.transitioned_at ||= Time.current
  end

  def to_stage_must_belong_to_hiring_process
    return unless application && to_stage

    unless to_stage.hiring_process_id == application.hiring_process_id
      errors.add(:to_stage, "must belong to the application's hiring process")
    end
  end

  def from_stage_must_belong_to_hiring_process
    return unless application && from_stage

    unless from_stage.hiring_process_id == application.hiring_process_id
      errors.add(:from_stage, "must belong to the application's hiring process")
    end
  end
end
