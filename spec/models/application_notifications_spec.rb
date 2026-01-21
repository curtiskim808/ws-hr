# Application Notifications Integration Spec - T138-T142
#
# PURPOSE: Test that Application callbacks correctly trigger NotificationJob
#
# TESTING PHILOSOPHY:
# - Test that specific actions enqueue specific notification jobs
# - Use ActiveJob::TestHelper to assert job enqueuing
# - Test transaction safety (rollback should NOT trigger notifications)
#
# KEY FEATURE:
# - All notification callbacks use after_commit
# - This means notifications only fire if transaction succeeds
#
# FIXTURES USED:
# - applications.yml: Various application states
# - applicants.yml: Applicant records
# - users.yml: Users for hire/reject actions
# - hiring_stages.yml: Stages for advance_to_stage!

require 'rails_helper'

RSpec.describe 'Application Notification Callbacks', type: :model do
  include ActiveJob::TestHelper

  # =============================================================================
  # SETUP
  # =============================================================================

  before(:each) do
    Current.brand = brands(:acme)
    Current.user = users(:acme_admin)
    # Clear enqueued jobs before each test
    clear_enqueued_jobs
  end

  after(:each) do
    Current.reset
  end

  # =============================================================================
  # T138: APPLICATION CREATION TRIGGERS :application_received
  # =============================================================================

  describe 'T138: Application creation notification' do
    let(:job_posting) { job_postings(:backend_engineer_published) }
    let(:applicant) { applicants(:jane_smith) } # Use jane_smith - doesn't have application to this job

    it 'enqueues :application_received notification when application is created' do
      # Create a new application - we need to bypass the uniqueness validation
      # by creating a new applicant
      new_applicant = Applicant.create!(
        brand: brands(:acme),
        first_name: 'New',
        last_name: 'Applicant',
        email: 'new.test@example.com',
        source: 'careers_page'
      )

      expect {
        Application.create!(
          brand: brands(:acme),
          applicant: new_applicant,
          job_posting: job_posting,
          hiring_process: job_posting.hiring_process,
          applied_at: Time.current,
          status: 'in_progress'
        )
      }.to have_enqueued_job(NotificationJob)
        .with(:application_received, anything)
        .on_queue('notifications')
    end

    it 'does not enqueue notification if application creation fails' do
      expect {
        begin
          # Try to create invalid application (missing required fields)
          Application.create!(
            brand: brands(:acme),
            applicant: nil, # Invalid - required
            job_posting: job_posting,
            status: 'in_progress'
          )
        rescue ActiveRecord::RecordInvalid
          # Expected to fail
        end
      }.not_to have_enqueued_job(NotificationJob)
    end
  end

  # =============================================================================
  # T139: APPLICATION#HIRE! TRIGGERS :candidate_hired
  # =============================================================================

  describe 'T139: Application#hire! notification' do
    let(:application) { applications(:technical_interview_application) }
    let(:hiring_manager) { users(:acme_hiring_manager) }

    it 'enqueues :candidate_hired notification when application is hired' do
      expect {
        application.hire!(hiring_manager)
      }.to have_enqueued_job(NotificationJob)
        .with(:candidate_hired, application.id)
        .on_queue('notifications')
    end

    it 'does not trigger notification for already hired application' do
      hired_app = applications(:hired_application)

      expect {
        begin
          hired_app.hire!(hiring_manager)
        rescue AASM::InvalidTransition
          # Expected - can't hire already hired application
        end
      }.not_to have_enqueued_job(NotificationJob)
        .with(:candidate_hired, anything)
    end
  end

  # =============================================================================
  # T140: APPLICATION#REJECT! TRIGGERS :candidate_rejected
  # =============================================================================

  describe 'T140: Application#reject! notification' do
    let(:application) { applications(:pending_application) }
    let(:hiring_manager) { users(:acme_hiring_manager) }

    it 'enqueues :candidate_rejected notification when application is rejected' do
      expect {
        application.reject!('Not enough experience', hiring_manager)
      }.to have_enqueued_job(NotificationJob)
        .with(:candidate_rejected, application.id)
        .on_queue('notifications')
    end

    it 'does not trigger notification for already rejected application' do
      rejected_app = applications(:rejected_application)

      expect {
        begin
          rejected_app.reject!('Another reason', hiring_manager)
        rescue AASM::InvalidTransition
          # Expected - can't reject already rejected application
        end
      }.not_to have_enqueued_job(NotificationJob)
        .with(:candidate_rejected, anything)
    end
  end

  # =============================================================================
  # T141: APPLICATION#ADVANCE_TO_STAGE! TRIGGERS :stage_changed
  # =============================================================================

  describe 'T141: Application#advance_to_stage! notification' do
    let(:application) { applications(:pending_application) }
    let(:phone_screen) { hiring_stages(:default_phone_screen) }
    let(:hiring_manager) { users(:acme_hiring_manager) }

    it 'enqueues :stage_changed notification when stage is advanced' do
      expect {
        application.advance_to_stage!(phone_screen, hiring_manager)
      }.to have_enqueued_job(NotificationJob)
        .with(:stage_changed, application.id)
        .on_queue('notifications')
    end

    it 'enqueues notification for each stage change' do
      technical = hiring_stages(:default_technical)

      # First advance
      application.advance_to_stage!(phone_screen, hiring_manager)
      clear_enqueued_jobs

      # Second advance should also trigger notification
      expect {
        application.advance_to_stage!(technical, hiring_manager)
      }.to have_enqueued_job(NotificationJob)
        .with(:stage_changed, application.id)
    end

    it 'does not trigger notification when advancing to invalid stage' do
      # Try to advance to a stage from different hiring process (executive)
      wrong_stage = hiring_stages(:executive_interview)

      expect {
        begin
          application.advance_to_stage!(wrong_stage, hiring_manager)
        rescue ArgumentError
          # Expected - stage not in this hiring process
        end
      }.not_to have_enqueued_job(NotificationJob)
        .with(:stage_changed, anything)
    end
  end

  # =============================================================================
  # T142: TRANSACTION ROLLBACK DOES NOT TRIGGER NOTIFICATIONS
  # =============================================================================

  describe 'T142: Transaction rollback safety' do
    let(:job_posting) { job_postings(:backend_engineer_published) }
    let(:hiring_manager) { users(:acme_hiring_manager) }

    it 'does not enqueue notification if transaction rolls back' do
      # Create a new applicant for testing
      new_applicant = Applicant.create!(
        brand: brands(:acme),
        first_name: 'Rollback',
        last_name: 'Test',
        email: 'rollback.test@example.com',
        source: 'test'
      )

      expect {
        begin
          Application.transaction do
            Application.create!(
              brand: brands(:acme),
              applicant: new_applicant,
              job_posting: job_posting,
              hiring_process: job_posting.hiring_process,
              applied_at: Time.current,
              status: 'in_progress'
            )
            # Force rollback
            raise ActiveRecord::Rollback
          end
        rescue
          # Catch any errors
        end
      }.not_to have_enqueued_job(NotificationJob)
    end

    it 'does not enqueue hire notification if hire transaction fails' do
      application = applications(:technical_interview_application)

      # Mock the save to fail after status change
      allow(application).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(application))

      expect {
        begin
          application.hire!(hiring_manager)
        rescue ActiveRecord::RecordInvalid
          # Expected
        end
      }.not_to have_enqueued_job(NotificationJob)
        .with(:candidate_hired, anything)
    end

    it 'verifies after_commit is used (not after_save)' do
      # This test documents that we use after_commit, not after_save
      # after_commit only fires if the transaction commits successfully
      callbacks = Application._commit_callbacks.select { |c| c.filter.to_s.include?('notification') }
      expect(callbacks).not_to be_empty
    end
  end

  # =============================================================================
  # MULTIPLE NOTIFICATIONS IN SINGLE OPERATION
  # =============================================================================

  describe 'notification isolation' do
    let(:application) { applications(:pending_application) }
    let(:hiring_manager) { users(:acme_hiring_manager) }

    it 'only triggers the appropriate notification type' do
      # Advance to stage should only trigger stage_changed, not other notifications
      phone_screen = hiring_stages(:default_phone_screen)

      expect {
        application.advance_to_stage!(phone_screen, hiring_manager)
      }.to have_enqueued_job(NotificationJob)
        .with(:stage_changed, anything)

      # And should NOT trigger other notification types
      expect(NotificationJob).not_to have_been_enqueued.with(:application_received, anything)
      expect(NotificationJob).not_to have_been_enqueued.with(:candidate_hired, anything)
    end
  end
end
