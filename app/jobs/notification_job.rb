# NotificationJob - SNS Event Publisher
# Create NotificationJob with perform method

class NotificationJob < ApplicationJob
  queue_as :notifications

  # RETRY: 3 attempts with exponential backoff (built-in to ActiveJob)
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # DISCARD: Don't retry if record was deleted (graceful degradation)
  discard_on ActiveRecord::RecordNotFound


  def perform(event_type, model_id)
    unless AwsConfig.sns_configured?
      Rails.logger.info "[NotificationJob] SNS not configured, skipping #{event_type} for model #{model_id}"
      return
    end

    payload = build_payload(event_type, model_id)

    publish_to_sns(payload)

    Rails.logger.info "[NotificationJob] Published #{event_type} notification for model #{model_id}"
  rescue StandardError => e
    # Log error but let retry_on handle the retry logic
    Rails.logger.error "[NotificationJob] Failed to publish #{event_type}: #{e.message}"
    raise
  end

  private


  def publish_to_sns(payload)
    response = AwsConfig.sns_client.publish(
      topic_arn: AwsConfig.sns_topic_arn,
      message: payload.to_json,
      message_attributes: {
        "event_type" => {
          data_type: "String",
          string_value: payload[:event_type].to_s
        },
        "brand_id" => {
          data_type: "Number",
          string_value: payload[:brand_id].to_s
        }
      }
    )

    Rails.logger.debug "[NotificationJob] SNS message_id: #{response.message_id}"
    response
  end


  def build_payload(event_type, model_id)
    case event_type.to_sym
    when :application_received
      build_application_received_payload(model_id)
    when :candidate_hired
      build_candidate_hired_payload(model_id)
    when :candidate_rejected
      build_candidate_rejected_payload(model_id)
    when :stage_changed
      build_stage_changed_payload(model_id)
    when :interview_scheduled
      build_interview_scheduled_payload(model_id)
    when :interview_cancelled
      build_interview_cancelled_payload(model_id)
    else
      raise ArgumentError, "Unknown event type: #{event_type}"
    end
  end


  def build_application_received_payload(application_id)
    application = Application.unscoped
                             .includes(:applicant, job_posting: :location)
                             .find(application_id)

    {
      event_type: :application_received,
      channel: "email",
      recipient: determine_recipient(application),
      payload: {
        application_id: application.id,
        applicant_name: application.applicant.full_name,
        applicant_email: application.applicant.email,
        job_title: application.job_posting.job_title,
        job_posting_id: application.job_posting_id,
        location_name: application.job_posting.location&.name,
        applied_at: application.applied_at.iso8601
      },
      timestamp: Time.current.iso8601,
      brand_id: application.brand_id
    }
  end


  def build_candidate_hired_payload(application_id)
    application = Application.unscoped
                             .includes(:applicant, :job_posting, :hired_by)
                             .find(application_id)

    {
      event_type: :candidate_hired,
      channel: "email",
      recipient: application.applicant.email,
      payload: {
        application_id: application.id,
        applicant_name: application.applicant.full_name,
        applicant_email: application.applicant.email,
        job_title: application.job_posting.job_title,
        job_posting_id: application.job_posting_id,
        hired_at: application.hired_at&.iso8601,
        hired_by_name: application.hired_by&.full_name
      },
      timestamp: Time.current.iso8601,
      brand_id: application.brand_id
    }
  end


  def build_candidate_rejected_payload(application_id)
    application = Application.unscoped
                             .includes(:applicant, :job_posting)
                             .find(application_id)

    {
      event_type: :candidate_rejected,
      channel: "email",
      recipient: application.applicant.email,
      payload: {
        application_id: application.id,
        applicant_email: application.applicant.email,
        applicant_name: application.applicant.full_name,
        job_title: application.job_posting.job_title,
        job_posting_id: application.job_posting_id,
        rejected_at: application.rejected_at&.iso8601
      },
      timestamp: Time.current.iso8601,
      brand_id: application.brand_id
    }
  end


  def build_stage_changed_payload(application_id)
    application = Application.unscoped
                             .includes(:applicant, :job_posting, :current_stage)
                             .find(application_id)

    {
      event_type: :stage_changed,
      channel: "email",
      recipient: determine_recipient(application),
      payload: {
        application_id: application.id,
        applicant_name: application.applicant.full_name,
        applicant_email: application.applicant.email,
        job_title: application.job_posting.job_title,
        job_posting_id: application.job_posting_id,
        new_stage_name: application.current_stage&.name,
        new_stage_id: application.current_stage_id
      },
      timestamp: Time.current.iso8601,
      brand_id: application.brand_id
    }
  end


  def build_interview_scheduled_payload(interview_id)
    unless defined?(Interview)
      Rails.logger.warn "[NotificationJob] Interview model not yet implemented"
      return {
        event_type: :interview_scheduled,
        channel: "email",
        recipient: "placeholder@example.com",
        payload: { interview_id: interview_id, message: "Interview model pending" },
        timestamp: Time.current.iso8601,
        brand_id: 0
      }
    end

    interview = Interview.unscoped
                         .includes(application: [ :applicant, :job_posting ], interviewer: [], location: [])
                         .find(interview_id)

    {
      event_type: :interview_scheduled,
      channel: "email",
      recipient: interview.application.applicant.email,
      payload: {
        interview_id: interview.id,
        application_id: interview.application_id,
        applicant_name: interview.application.applicant.full_name,
        applicant_email: interview.application.applicant.email,
        job_title: interview.application.job_posting.job_title,
        interview_time: interview.scheduled_at&.iso8601,
        duration_minutes: interview.duration_minutes,
        meeting_type: interview.meeting_type,
        location_name: interview.location&.name,
        interviewer_name: interview.interviewer&.full_name,
        interviewer_email: interview.interviewer&.email
      },
      timestamp: Time.current.iso8601,
      brand_id: interview.brand_id
    }
  end


  def build_interview_cancelled_payload(interview_id)
    unless defined?(Interview)
      Rails.logger.warn "[NotificationJob] Interview model not yet implemented"
      return {
        event_type: :interview_cancelled,
        channel: "email",
        recipient: "placeholder@example.com",
        payload: { interview_id: interview_id, message: "Interview model pending" },
        timestamp: Time.current.iso8601,
        brand_id: 0
      }
    end

    interview = Interview.unscoped
                         .includes(application: [ :applicant, :job_posting ], interviewer: [])
                         .find(interview_id)

    {
      event_type: :interview_cancelled,
      channel: "email",
      recipient: interview.application.applicant.email,
      payload: {
        interview_id: interview.id,
        application_id: interview.application_id,
        applicant_email: interview.application.applicant.email,
        applicant_name: interview.application.applicant.full_name,
        job_title: interview.application.job_posting.job_title,
        original_time: interview.scheduled_at&.iso8601,
        cancellation_reason: interview.cancellation_reason,
        cancelled_at: interview.cancelled_at&.iso8601
      },
      timestamp: Time.current.iso8601,
      brand_id: interview.brand_id
    }
  end


  def determine_recipient(application)
    location = application.job_posting.location
    return "hiring@example.com" unless location

    hiring_manager = User.unscoped
                         .joins(:location_assignments)
                         .where(brand_id: application.brand_id)
                         .where(role: :hiring_manager)
                         .where(location_assignments: { location_id: location.id })
                         .first

    hiring_manager&.email || "hiring@example.com"
  end
end
