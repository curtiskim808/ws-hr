# Application Model - ,
# Represent a job application (applicant applying to a job posting)

class Application < ApplicationRecord
  # MULTI-TENANT SCOPING
  # Automatically scope all queries by Current.brand
  include BrandScoped

  include AASM


  # PARENT: Brand
  # REQUIREMENT: Every application belongs to exactly one brand
  belongs_to :brand

  belongs_to :applicant

  belongs_to :job_posting

  belongs_to :hiring_process

  belongs_to :current_stage, class_name: "HiringStage", optional: true

  belongs_to :hired_by, class_name: "User", optional: true

  belongs_to :rejected_by, class_name: "User", optional: true


  has_many :stage_transitions,
           class_name: "ApplicationStageTransition",
           dependent: :destroy,
           inverse_of: :application,
           autosave: true

  attribute :status, :integer, default: 0
  enum :status, { in_progress: 0, hired: 1, rejected: 2, archived: 3 }, prefix: false


  aasm column: :status, enum: true do
    state :in_progress, initial: true

    state :hired

    state :rejected

    state :archived


    event :hire do
      transitions from: :in_progress, to: :hired, guard: :can_hire?
    end

    event :reject do
      transitions from: :in_progress, to: :rejected, guard: :can_reject?
    end

    event :archive do
      transitions from: [ :in_progress, :hired, :rejected ], to: :archived
    end
  end


  validates :applicant_id, uniqueness: {
    scope: :job_posting_id,
    message: "has already applied to this job posting"
  }

  validates :applied_at, presence: true


  def hire!(user)
    self.hired_by = user
    self.hired_at = Time.current
    aasm.fire(:hire) # Call AASM event (not self.hire! which would be recursive)
    save!
  end

  def reject!(reason, user)
    self.rejection_reason = reason
    self.rejected_by = user
    self.rejected_at = Time.current
    aasm.fire(:reject) # Call AASM event (not self.reject! which would be recursive)
    save!
  end

  def archive!
    self.archived_at = Time.current
    aasm.fire(:archive) # Call AASM event (not self.archive! which would be recursive)
    save!
  end

  def advance_to_stage!(stage, user = nil, notes = nil)
    unless stage.hiring_process_id == hiring_process_id
      raise ArgumentError, "Stage must belong to this application's hiring process"
    end

    from_stage = current_stage

    stage_transitions.build(
      from_stage: from_stage,
      to_stage: stage,
      transitioned_by: user,
      transitioned_at: Time.current,
      notes: notes
    )

    self.current_stage = stage
    save!
  end


  scope :with_applicant, -> { includes(:applicant) }

  scope :with_job_posting, -> { includes(:job_posting) }

  scope :recent, -> { order(created_at: :desc) }

  scope :for_location, ->(location_id) {
    joins(:job_posting).where(job_postings: { location_id: location_id })
  }

  scope :by_status, ->(status) { where(status: status) }


  scope :with_transitions, -> {
    includes(stage_transitions: [ :from_stage, :to_stage, :transitioned_by ])
  }


  # Create application from public form submission
  def self.create_from_form!(params)
    transaction do
      applicant_params = params[:applicant] || params["applicant"]
      applicant = Applicant.find_or_create_by!(
        brand_id: Current.brand.id,
        email: applicant_params[:email] || applicant_params["email"]
      ) do |a|
        a.first_name = applicant_params[:first_name] || applicant_params["first_name"]
        a.last_name = applicant_params[:last_name] || applicant_params["last_name"]
        a.phone = applicant_params[:phone] || applicant_params["phone"]
        a.source = applicant_params[:source] || applicant_params["source"]
        a.preferred_language = applicant_params[:preferred_language] || applicant_params["preferred_language"] || "en"
      end

      job_posting = JobPosting.find(params[:job_posting_id] || params["job_posting_id"])

      application = create!(
        brand_id: Current.brand.id,
        applicant: applicant,
        job_posting: job_posting,
        hiring_process: job_posting.hiring_process,
        current_stage: job_posting.hiring_process.first_stage,
        applied_at: Time.current,
        notes: params[:notes] || params["notes"]
      )

      application
    end
  end


  after_commit :publish_received_notification, on: :create

  after_commit :publish_hired_notification, if: :saved_change_to_hired_status?

  after_commit :publish_rejected_notification, if: :saved_change_to_rejected_status?

  after_commit :publish_stage_changed_notification, if: :saved_change_to_current_stage_id?


  def can_hire?
    in_progress?
  end

  def can_reject?
    in_progress?
  end

  private


  def publish_received_notification
    Rails.logger.info "[Application] Publishing :application_received notification for ##{id}"
    NotificationJob.perform_later(:application_received, id)
  rescue StandardError => e
    Rails.logger.error "[Application] Failed to enqueue :application_received notification: #{e.message}"
  end

  def publish_hired_notification
    Rails.logger.info "[Application] Publishing :candidate_hired notification for ##{id}"
    NotificationJob.perform_later(:candidate_hired, id)
  rescue StandardError => e
    Rails.logger.error "[Application] Failed to enqueue :candidate_hired notification: #{e.message}"
  end

  def publish_rejected_notification
    Rails.logger.info "[Application] Publishing :candidate_rejected notification for ##{id}"
    NotificationJob.perform_later(:candidate_rejected, id)
  rescue StandardError => e
    Rails.logger.error "[Application] Failed to enqueue :candidate_rejected notification: #{e.message}"
  end

  def publish_stage_changed_notification
    Rails.logger.info "[Application] Publishing :stage_changed notification for ##{id} to stage: #{current_stage&.name}"
    NotificationJob.perform_later(:stage_changed, id)
  rescue StandardError => e
    Rails.logger.error "[Application] Failed to enqueue :stage_changed notification: #{e.message}"
  end


  def saved_change_to_hired_status?
    saved_change_to_status? && status == "hired"
  end

  def saved_change_to_rejected_status?
    saved_change_to_status? && status == "rejected"
  end
end
