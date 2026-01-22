# NotificationJob - SNS Event Publisher
#
# T119 [P2] [US8] Create NotificationJob with perform method
# T120 [P2] [US8] Add publish_to_sns method with error handling and retry
# T121 [P2] [US8] Add build_payload method for all event types
# T122 [P2] [US8] Configure retry settings (retry: 3, dead: false)
#
# PURPOSE: Publish notification events to AWS SNS topic
# WHY: Decouples HR system from notification delivery (fire-and-forget)
# PATTERN: Background job publishes structured event, notification service subscribes
#
# QUEUE: notifications (separate from default for independent scaling)
# RETRY: 3 attempts with exponential backoff
# DEAD JOBS: Logged but not raised (graceful degradation)
#
# EVENT TYPES:
#   - :application_received - New application submitted
#   - :candidate_hired - Applicant was hired
#   - :candidate_rejected - Applicant was rejected
#   - :stage_changed - Application moved to new stage
#   - :interview_scheduled - Interview was scheduled
#   - :interview_cancelled - Interview was cancelled
#
# PAYLOAD STRUCTURE:
#   {
#     "event_type": "application_received",
#     "channel": "email",
#     "recipient": "hiring-manager@company.com",
#     "payload": { ... event-specific data ... },
#     "timestamp": "2026-01-21T10:30:00Z",
#     "brand_id": 1
#   }
#
# USAGE:
#   NotificationJob.perform_later(:application_received, application.id)
#   NotificationJob.perform_later(:candidate_hired, application.id)
#   NotificationJob.perform_later(:interview_scheduled, interview.id)

class NotificationJob < ApplicationJob
  # QUEUE: Use dedicated notifications queue for independent scaling
  # WHY: Notification volume shouldn't impact other job processing
  queue_as :notifications

  # RETRY: 3 attempts with exponential backoff (built-in to ActiveJob)
  # T122: Configure retry settings
  # PATTERN: Wait 3^attempt seconds between retries (3, 9, 27 seconds)
  # WHY: Give transient failures time to resolve
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # DISCARD: Don't retry if record was deleted (graceful degradation)
  # WHY: If Application/Interview no longer exists, skip notification
  discard_on ActiveRecord::RecordNotFound

  # =============================================================================
  # T119: MAIN PERFORM METHOD
  # =============================================================================

  # PERFORM: Publish notification event to SNS
  # PARAMS:
  #   - event_type: Symbol (:application_received, :candidate_hired, etc.)
  #   - model_id: Integer ID of the Application or Interview
  # IMPLEMENTATION:
  #   1. Build event payload from model data
  #   2. Publish to SNS topic
  #   3. Log success/failure
  # GRACEFUL DEGRADATION:
  #   - If SNS not configured, log and skip
  #   - If publish fails after retries, log but don't raise
  #
  # EXAMPLE:
  #   NotificationJob.perform_later(:application_received, 123)
  def perform(event_type, model_id)
    # Skip if SNS not configured (local development without AWS)
    unless AwsConfig.sns_configured?
      Rails.logger.info "[NotificationJob] SNS not configured, skipping #{event_type} for model #{model_id}"
      return
    end

    # Build the event payload
    payload = build_payload(event_type, model_id)

    # Publish to SNS
    publish_to_sns(payload)

    Rails.logger.info "[NotificationJob] Published #{event_type} notification for model #{model_id}"
  rescue StandardError => e
    # Log error but let retry_on handle the retry logic
    Rails.logger.error "[NotificationJob] Failed to publish #{event_type}: #{e.message}"
    raise
  end

  private

  # =============================================================================
  # T120: PUBLISH TO SNS
  # =============================================================================

  # PRIVATE: Publish payload to AWS SNS topic
  # PARAMS:
  #   - payload: Hash with event data
  # IMPLEMENTATION:
  #   - Convert payload to JSON
  #   - Call SNS publish API
  #   - Return message_id on success
  # ERROR HANDLING:
  #   - Aws::SNS::Errors::ServiceError - Retry
  #   - Other errors - Log and raise for retry
  #
  # EXAMPLE PAYLOAD:
  #   {
  #     event_type: "application_received",
  #     channel: "email",
  #     recipient: "hiring@example.com",
  #     payload: { applicant_name: "John Doe", job_title: "Engineer" },
  #     timestamp: "2026-01-21T10:30:00Z",
  #     brand_id: 1
  #   }
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

  # =============================================================================
  # T121: BUILD PAYLOAD - DISPATCHER
  # =============================================================================

  # PRIVATE: Build event payload based on event type
  # PARAMS:
  #   - event_type: Symbol (:application_received, :candidate_hired, etc.)
  #   - model_id: Integer ID of the model
  # RETURNS: Hash with structured event data
  # IMPLEMENTATION: Case statement dispatches to specific builder methods
  #
  # WHY CASE STATEMENT:
  #   - Each event type has different payload requirements
  #   - Explicit mapping makes code readable and maintainable
  #   - Easy to add new event types
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

  # =============================================================================
  # T128: APPLICATION_RECEIVED PAYLOAD
  # =============================================================================

  # PRIVATE: Build payload for :application_received event
  # T128 [P2] [US8] Implement payload builder for :application_received
  #
  # DATA INCLUDED:
  #   - applicant_name: Full name of the applicant
  #   - job_title: Title of the job posting
  #   - applied_at: When the application was submitted
  #   - application_id: For reference/linking
  #
  # RECIPIENT: Hiring manager email (via job posting location assignment)
  # CHANNEL: email
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

  # =============================================================================
  # T129: CANDIDATE_HIRED PAYLOAD
  # =============================================================================

  # PRIVATE: Build payload for :candidate_hired event
  # T129 [P2] [US8] Implement payload builder for :candidate_hired
  #
  # DATA INCLUDED:
  #   - applicant_name: Full name of the hired candidate
  #   - job_title: Title they were hired for
  #   - hired_at: When they were hired
  #   - hired_by: Name of user who made hiring decision
  #
  # RECIPIENT: Applicant email (congratulations notification)
  # CHANNEL: email
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

  # =============================================================================
  # T130: CANDIDATE_REJECTED PAYLOAD
  # =============================================================================

  # PRIVATE: Build payload for :candidate_rejected event
  # T130 [P2] [US8] Implement payload builder for :candidate_rejected
  #
  # DATA INCLUDED:
  #   - applicant_email: Email for sending rejection notification
  #   - Note: Notification service determines content (reason not sent to applicant)
  #
  # WHY MINIMAL DATA:
  #   - Rejection email content is managed by notification service
  #   - Keeps sensitive rejection reasons out of notification pipeline
  #
  # RECIPIENT: Applicant email
  # CHANNEL: email
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
        # Note: rejection_reason intentionally not included for privacy
      },
      timestamp: Time.current.iso8601,
      brand_id: application.brand_id
    }
  end

  # =============================================================================
  # T131: STAGE_CHANGED PAYLOAD
  # =============================================================================

  # PRIVATE: Build payload for :stage_changed event
  # T131 [P2] [US8] Implement payload builder for :stage_changed
  #
  # DATA INCLUDED:
  #   - applicant_name: Who moved to new stage
  #   - new_stage_name: Name of the stage they moved to
  #   - job_title: Which job posting
  #
  # RECIPIENT: Hiring team (determined by role/location)
  # CHANNEL: email or in-app
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

  # =============================================================================
  # T134: INTERVIEW_SCHEDULED PAYLOAD
  # =============================================================================

  # PRIVATE: Build payload for :interview_scheduled event
  # T134 [P2] [US8] Implement payload builder for :interview_scheduled
  #
  # DATA INCLUDED:
  #   - applicant_name: Who the interview is for
  #   - interview_time: When the interview is scheduled
  #   - location: Where (physical) or meeting_type (virtual)
  #   - meeting_type: phone, video, or on_site
  #
  # NOTE: Interview model not yet implemented (Phase 10)
  # This is a placeholder that will be activated when Interview model exists
  #
  # RECIPIENT: Applicant email + Interviewer email
  # CHANNEL: email
  def build_interview_scheduled_payload(interview_id)
    # Interview model will be implemented in Phase 10 (T179-T196)
    # For now, return a placeholder structure
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

  # =============================================================================
  # T135: INTERVIEW_CANCELLED PAYLOAD
  # =============================================================================

  # PRIVATE: Build payload for :interview_cancelled event
  # T135 [P2] [US8] Implement payload builder for :interview_cancelled
  #
  # DATA INCLUDED:
  #   - applicant_email: For notification delivery
  #   - original_time: When the interview was scheduled
  #   - cancellation_reason: Why it was cancelled (if provided)
  #
  # NOTE: Interview model not yet implemented (Phase 10)
  # This is a placeholder that will be activated when Interview model exists
  #
  # RECIPIENT: Applicant email + Interviewer email
  # CHANNEL: email
  def build_interview_cancelled_payload(interview_id)
    # Interview model will be implemented in Phase 10 (T179-T196)
    # For now, return a placeholder structure
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

  # =============================================================================
  # HELPER METHODS
  # =============================================================================

  # PRIVATE: Determine recipient for internal notifications
  # LOGIC: Find hiring manager assigned to the job posting's location
  # FALLBACK: Brand admin email if no specific manager found
  def determine_recipient(application)
    # Find hiring managers assigned to this location
    location = application.job_posting.location
    return "hiring@example.com" unless location

    # Find users with hiring_manager role assigned to this location
    hiring_manager = User.unscoped
                         .joins(:location_assignments)
                         .where(brand_id: application.brand_id)
                         .where(role: :hiring_manager)
                         .where(location_assignments: { location_id: location.id })
                         .first

    hiring_manager&.email || "hiring@example.com"
  end
end
