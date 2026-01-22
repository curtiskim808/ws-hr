# ApplicationSerializer - JSON:API formatted serialization for applications

class ApplicationSerializer
  include JSONAPI::Serializer


  attributes :status

  attributes :applied_at,
             :hired_at,
             :rejected_at,
             :archived_at

  attributes :rejection_reason

  attributes :notes

  attributes :created_at,
             :updated_at


  attribute :status_label do |application|
    application.status.humanize
  end

  attribute :days_since_applied do |application|
    ((Time.current - application.applied_at) / 1.day).floor
  end

  attribute :current_stage_name do |application|
    application.current_stage&.name
  end

  attribute :applicant_name do |application|
    application.applicant.full_name
  end

  attribute :job_title do |application|
    application.job_posting.job_title
  end

  attribute :hired_by_name do |application|
    application.hired_by&.full_name
  end

  attribute :rejected_by_name do |application|
    application.rejected_by&.full_name
  end

  attribute :stage_transitions_count do |application|
    application.stage_transitions.count
  end


  belongs_to :applicant, serializer: ApplicantSerializer

  belongs_to :job_posting, serializer: JobPostingSerializer

  belongs_to :current_stage, serializer: HiringStageSerializer

  belongs_to :hiring_process

  belongs_to :hired_by, serializer: UserSerializer

  belongs_to :rejected_by, serializer: UserSerializer

  has_many :stage_transitions, serializer: ApplicationStageTransitionSerializer
end
