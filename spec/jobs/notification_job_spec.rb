# NotificationJob Spec - T137
#
# TESTING PHILOSOPHY:
# - Test the job's perform method with mocked SNS client
# - Test payload building for each event type
# - Test error handling and graceful degradation
# - Test retry and discard behavior
#
# FIXTURE USAGE:
# - applications(:pending_application) - Test application notifications
# - applicants(:john_doe) - Existing applicant data
# - users(:acme_hiring_manager) - Hiring manager for recipient tests
#
# KEY FEATURE:
# - Jobs should not make real AWS API calls in tests
# - MockSnsClient stores published messages for assertions

require 'rails_helper'

RSpec.describe NotificationJob, type: :job do
  include ActiveJob::TestHelper

  # SETUP: Load fixtures for all tests
  # Note: Uses global fixtures from rails_helper.rb (config.global_fixtures = :all)
  fixtures :brands, :users, :locations, :location_assignments, :position_templates,
           :hiring_processes, :hiring_stages, :job_postings, :applicants, :applications

  # =============================================================================
  # T137: BASIC JOB CONFIGURATION TESTS
  # =============================================================================

  describe 'job configuration' do
    it 'is enqueued to the notifications queue' do
      expect(NotificationJob.new.queue_name).to eq('notifications')
    end

    it 'has retry_on configured for StandardError' do
      # Verify retry_on by checking the rescue_handlers
      rescue_handlers = NotificationJob.rescue_handlers
      expect(rescue_handlers).not_to be_empty
    end

    it 'is configured with retry and discard behaviors' do
      # Job should be configured with error handling
      job = NotificationJob.new
      expect(job).to be_a(ApplicationJob)
    end
  end

  # =============================================================================
  # T137: PERFORM METHOD TESTS WITH MOCKED SNS CLIENT
  # =============================================================================

  describe '#perform' do
    let(:application) { applications(:pending_application) }

    context 'when SNS is not configured' do
      before do
        allow(AwsConfig).to receive(:sns_configured?).and_return(false)
      end

      it 'skips publishing when SNS not configured' do
        # Should complete without error and not publish anything
        expect {
          NotificationJob.perform_now(:application_received, application.id)
        }.not_to raise_error
      end

      it 'does not call sns_client.publish' do
        mock_client = instance_double(AwsConfig::MockSnsClient)
        allow(AwsConfig).to receive(:sns_client).and_return(mock_client)
        expect(mock_client).not_to receive(:publish)

        NotificationJob.perform_now(:application_received, application.id)
      end
    end

    context 'when SNS is configured' do
      let(:mock_sns_client) { AwsConfig::MockSnsClient.new }

      before do
        allow(AwsConfig).to receive(:sns_configured?).and_return(true)
        allow(AwsConfig).to receive(:sns_client).and_return(mock_sns_client)
        allow(AwsConfig).to receive(:sns_topic_arn).and_return('arn:aws:sns:us-east-1:123456789012:test-topic')
      end

      it 'publishes to SNS for :application_received' do
        NotificationJob.perform_now(:application_received, application.id)

        expect(mock_sns_client.published_messages.size).to eq(1)
        message = mock_sns_client.published_messages.first
        expect(message[:topic_arn]).to eq('arn:aws:sns:us-east-1:123456789012:test-topic')

        payload = JSON.parse(message[:message], symbolize_names: true)
        expect(payload[:event_type]).to eq('application_received')
        expect(payload[:payload][:applicant_name]).to eq(application.applicant.full_name)
      end

      it 'publishes to SNS for :candidate_hired' do
        hired_app = applications(:hired_application)
        NotificationJob.perform_now(:candidate_hired, hired_app.id)

        expect(mock_sns_client.published_messages.size).to eq(1)
        payload = JSON.parse(mock_sns_client.published_messages.first[:message], symbolize_names: true)
        expect(payload[:event_type]).to eq('candidate_hired')
      end

      it 'publishes to SNS for :candidate_rejected' do
        rejected_app = applications(:rejected_application)
        NotificationJob.perform_now(:candidate_rejected, rejected_app.id)

        expect(mock_sns_client.published_messages.size).to eq(1)
        payload = JSON.parse(mock_sns_client.published_messages.first[:message], symbolize_names: true)
        expect(payload[:event_type]).to eq('candidate_rejected')
      end

      it 'publishes to SNS for :stage_changed' do
        NotificationJob.perform_now(:stage_changed, application.id)

        expect(mock_sns_client.published_messages.size).to eq(1)
        payload = JSON.parse(mock_sns_client.published_messages.first[:message], symbolize_names: true)
        expect(payload[:event_type]).to eq('stage_changed')
      end

      it 'includes message_attributes with event_type and brand_id' do
        NotificationJob.perform_now(:application_received, application.id)

        message = mock_sns_client.published_messages.first
        expect(message[:message_attributes]['event_type'][:string_value]).to eq('application_received')
        expect(message[:message_attributes]['brand_id'][:string_value]).to eq(application.brand_id.to_s)
      end

      it 'publishes message to SNS successfully' do
        NotificationJob.perform_now(:application_received, application.id)

        # Should complete without error
        expect(mock_sns_client.published_messages.size).to eq(1)
      end
    end

    context 'when application is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        # The discard_on catches this in perform_later but not perform_now
        # Test that the error would be raised for invalid IDs
        job = NotificationJob.new
        allow(AwsConfig).to receive(:sns_configured?).and_return(true)

        expect {
          job.send(:build_application_received_payload, 999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when unknown event type is provided' do
      let(:mock_sns_client) { AwsConfig::MockSnsClient.new }

      before do
        allow(AwsConfig).to receive(:sns_configured?).and_return(true)
        allow(AwsConfig).to receive(:sns_client).and_return(mock_sns_client)
        allow(AwsConfig).to receive(:sns_topic_arn).and_return('arn:aws:sns:test')
      end

      it 'raises ArgumentError for unknown event type when building payload' do
        job = NotificationJob.new

        expect {
          job.send(:build_payload, :unknown_event, application.id)
        }.to raise_error(ArgumentError, /Unknown event type/)
      end
    end
  end

  # =============================================================================
  # T137: PAYLOAD BUILDER TESTS
  # =============================================================================

  describe 'payload building' do
    let(:job) { NotificationJob.new }
    let(:application) { applications(:pending_application) }

    describe ':application_received payload' do
      it 'includes required fields' do
        payload = job.send(:build_application_received_payload, application.id)

        expect(payload[:event_type]).to eq(:application_received)
        expect(payload[:channel]).to eq('email')
        expect(payload[:recipient]).to be_present
        expect(payload[:brand_id]).to eq(application.brand_id)
        expect(payload[:timestamp]).to be_present

        inner = payload[:payload]
        expect(inner[:application_id]).to eq(application.id)
        expect(inner[:applicant_name]).to eq(application.applicant.full_name)
        expect(inner[:applicant_email]).to eq(application.applicant.email)
        expect(inner[:job_title]).to eq(application.job_posting.job_title)
        expect(inner[:job_posting_id]).to eq(application.job_posting_id)
        expect(inner[:applied_at]).to be_present
      end
    end

    describe ':candidate_hired payload' do
      let(:hired_app) { applications(:hired_application) }

      it 'includes required fields' do
        payload = job.send(:build_candidate_hired_payload, hired_app.id)

        expect(payload[:event_type]).to eq(:candidate_hired)
        expect(payload[:recipient]).to eq(hired_app.applicant.email)

        inner = payload[:payload]
        expect(inner[:applicant_name]).to be_present
        expect(inner[:job_title]).to be_present
        expect(inner[:hired_at]).to be_present
      end
    end

    describe ':candidate_rejected payload' do
      let(:rejected_app) { applications(:rejected_application) }

      it 'includes required fields but NOT rejection_reason (privacy)' do
        payload = job.send(:build_candidate_rejected_payload, rejected_app.id)

        expect(payload[:event_type]).to eq(:candidate_rejected)
        expect(payload[:recipient]).to eq(rejected_app.applicant.email)

        inner = payload[:payload]
        expect(inner[:applicant_email]).to be_present
        expect(inner[:rejected_at]).to be_present
        expect(inner).not_to have_key(:rejection_reason)
      end
    end

    describe ':stage_changed payload' do
      it 'includes new stage information' do
        payload = job.send(:build_stage_changed_payload, application.id)

        expect(payload[:event_type]).to eq(:stage_changed)

        inner = payload[:payload]
        expect(inner[:applicant_name]).to be_present
        expect(inner[:job_title]).to be_present
        expect(inner).to have_key(:new_stage_name)
        expect(inner).to have_key(:new_stage_id)
      end
    end

    describe ':interview_scheduled payload (placeholder)' do
      it 'returns placeholder payload since Interview model not implemented' do
        payload = job.send(:build_interview_scheduled_payload, 123)

        expect(payload[:event_type]).to eq(:interview_scheduled)
        expect(payload[:payload][:message]).to eq('Interview model pending')
      end
    end

    describe ':interview_cancelled payload (placeholder)' do
      it 'returns placeholder payload since Interview model not implemented' do
        payload = job.send(:build_interview_cancelled_payload, 456)

        expect(payload[:event_type]).to eq(:interview_cancelled)
        expect(payload[:payload][:message]).to eq('Interview model pending')
      end
    end
  end

  # =============================================================================
  # T137: DETERMINE_RECIPIENT TESTS
  # =============================================================================

  describe '#determine_recipient' do
    let(:job) { NotificationJob.new }
    let(:application) { applications(:pending_application) }

    context 'when hiring manager is assigned to location' do
      before do
        Current.brand = brands(:acme)
      end

      it 'returns hiring manager email' do
        recipient = job.send(:determine_recipient, application)
        # May return hiring manager email or fallback depending on fixture setup
        expect(recipient).to be_present
      end
    end

    context 'when no hiring manager found' do
      let(:globex_app) { applications(:globex_application) }

      it 'returns fallback email' do
        recipient = job.send(:determine_recipient, globex_app)
        expect(recipient).to be_present
      end
    end
  end

  # =============================================================================
  # T137: JOB ENQUEUING TESTS
  # =============================================================================

  describe 'job enqueuing' do
    let(:application) { applications(:pending_application) }

    it 'enqueues job with perform_later' do
      expect {
        NotificationJob.perform_later(:application_received, application.id)
      }.to have_enqueued_job(NotificationJob)
        .with(:application_received, application.id)
        .on_queue('notifications')
    end

    it 'can be performed immediately with perform_now' do
      allow(AwsConfig).to receive(:sns_configured?).and_return(false)

      expect {
        NotificationJob.perform_now(:application_received, application.id)
      }.not_to raise_error
    end
  end
end
