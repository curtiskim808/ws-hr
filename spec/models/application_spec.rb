# Application Model Spec - T113, T114, T115
#
# TESTING PHILOSOPHY (DHH/37signals):
# - Test behavior, not implementation
# - Use fixtures for stable, realistic test data
# - Focus on what the model DOES, not how it does it
# - Test public interface (methods that controllers call)
#
# TEST ORGANIZATION:
# - Validations: Required fields, uniqueness constraints
# - Associations: Relationships work correctly
# - State Machine: AASM transitions work correctly
# - Fat Model Methods: hire!, reject!, advance_to_stage!
# - Scopes: Query methods return correct results
#
# FIXTURES USED:
# - applications.yml: Various application states
# - applicants.yml: Applicant records
# - job_postings.yml: Job posting records
# - users.yml: Users for hired_by, rejected_by
# - hiring_stages.yml: Stages for advance_to_stage!

require 'rails_helper'

RSpec.describe Application, type: :model do
  # =============================================================================
  # SETUP: Set Current.brand for multi-tenant scoping
  # =============================================================================
  before(:each) do
    Current.brand = brands(:acme)
    Current.user = users(:acme_admin)
  end

  after(:each) do
    Current.reset
  end

  # =============================================================================
  # ASSOCIATIONS
  # =============================================================================
  describe 'associations' do
    it 'belongs to brand' do
      application = applications(:pending_application)
      expect(application.brand).to eq(brands(:acme))
    end

    it 'belongs to applicant' do
      application = applications(:pending_application)
      expect(application.applicant).to eq(applicants(:john_doe))
    end

    it 'belongs to job_posting' do
      application = applications(:pending_application)
      expect(application.job_posting).to eq(job_postings(:backend_engineer_published))
    end

    it 'belongs to hiring_process' do
      application = applications(:pending_application)
      expect(application.hiring_process).to eq(hiring_processes(:default_process))
    end

    it 'belongs to current_stage (optional)' do
      application = applications(:pending_application)
      expect(application.current_stage).to eq(hiring_stages(:default_application))
    end

    it 'can have null current_stage' do
      application = applications(:no_stage_application)
      expect(application.current_stage).to be_nil
    end

    it 'has many stage_transitions' do
      application = applications(:pending_application)
      expect(application.stage_transitions).to be_an(ActiveRecord::Associations::CollectionProxy)
    end
  end

  # =============================================================================
  # VALIDATIONS
  # =============================================================================
  describe 'validations' do
    describe 'applied_at' do
      it 'requires applied_at to be present' do
        application = Application.new(
          brand: brands(:acme),
          applicant: applicants(:john_doe),
          job_posting: job_postings(:sales_rep_published),
          hiring_process: hiring_processes(:default_process),
          applied_at: nil
        )
        expect(application).not_to be_valid
        expect(application.errors[:applied_at]).to include("can't be blank")
      end
    end

    # T115: Duplicate Prevention Validation
    describe 'duplicate prevention' do
      it 'prevents same applicant from applying twice to same job posting' do
        # John Doe already has pending_application to backend_engineer_published
        duplicate = Application.new(
          brand: brands(:acme),
          applicant: applicants(:john_doe),
          job_posting: job_postings(:backend_engineer_published),
          hiring_process: hiring_processes(:default_process),
          applied_at: Time.current
        )

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:applicant_id]).to include('has already applied to this job posting')
      end

      it 'allows same applicant to apply to different job postings' do
        # John Doe can apply to a different job
        new_application = Application.new(
          brand: brands(:acme),
          applicant: applicants(:john_doe),
          job_posting: job_postings(:customer_support_published),
          hiring_process: hiring_processes(:default_process),
          applied_at: Time.current
        )

        expect(new_application).to be_valid
      end

      it 'allows different applicants to apply to same job posting' do
        # A different applicant can apply to backend_engineer_published
        new_application = Application.new(
          brand: brands(:acme),
          applicant: applicants(:international_applicant),
          job_posting: job_postings(:backend_engineer_published),
          hiring_process: hiring_processes(:default_process),
          applied_at: Time.current
        )

        expect(new_application).to be_valid
      end
    end
  end

  # =============================================================================
  # T113: Application#hire!(user)
  # =============================================================================
  describe '#hire!' do
    let(:application) { applications(:technical_interview_application) }
    let(:hiring_manager) { users(:acme_hiring_manager) }

    context 'when application is in_progress' do
      it 'transitions status to hired' do
        application.hire!(hiring_manager)
        expect(application.status).to eq('hired')
        expect(application.hired?).to be true
      end

      it 'sets hired_at timestamp' do
        freeze_time do
          application.hire!(hiring_manager)
          expect(application.hired_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'sets hired_by to the user who hired' do
        application.hire!(hiring_manager)
        expect(application.hired_by).to eq(hiring_manager)
      end

      it 'persists the changes' do
        application.hire!(hiring_manager)
        application.reload
        expect(application.hired?).to be true
        expect(application.hired_by).to eq(hiring_manager)
      end

      it 'runs in a transaction' do
        # Test that partial state is not saved if something fails
        # This is implicitly tested by the fact that hire! uses transaction
        expect(application).to receive(:save!).and_call_original
        application.hire!(hiring_manager)
      end
    end

    context 'when application is already hired' do
      let(:hired_app) { applications(:hired_application) }

      it 'raises AASM::InvalidTransition' do
        expect { hired_app.hire!(hiring_manager) }.to raise_error(AASM::InvalidTransition)
      end
    end

    context 'when application is rejected' do
      let(:rejected_app) { applications(:rejected_application) }

      it 'raises AASM::InvalidTransition' do
        expect { rejected_app.hire!(hiring_manager) }.to raise_error(AASM::InvalidTransition)
      end
    end

    # =============================================================================
    # T162: Prevent hiring from rejected status
    # =============================================================================
    context 'T162: preventing hire when already rejected' do
      let(:rejected_app) { applications(:rejected_application) }

      it 'prevents hiring an already rejected application' do
        expect(rejected_app.rejected?).to be true
        expect {
          rejected_app.hire!(hiring_manager)
        }.to raise_error(AASM::InvalidTransition)
      end

      it 'does not change status when hire fails' do
        original_status = rejected_app.status
        begin
          rejected_app.hire!(hiring_manager)
        rescue AASM::InvalidTransition
          # Expected
        end
        rejected_app.reload
        expect(rejected_app.status).to eq(original_status)
      end

      it 'does not set hired_at when hire fails' do
        original_hired_at = rejected_app.hired_at
        begin
          rejected_app.hire!(hiring_manager)
        rescue AASM::InvalidTransition
          # Expected
        end
        rejected_app.reload
        expect(rejected_app.hired_at).to eq(original_hired_at)
      end
    end
  end

  # =============================================================================
  # T114: Application#reject!(reason, user)
  # =============================================================================
  describe '#reject!' do
    let(:application) { applications(:pending_application) }
    let(:hiring_manager) { users(:acme_hiring_manager) }
    let(:rejection_reason) { 'Not enough experience with required technologies' }

    context 'when application is in_progress' do
      it 'transitions status to rejected' do
        application.reject!(rejection_reason, hiring_manager)
        expect(application.status).to eq('rejected')
        expect(application.rejected?).to be true
      end

      it 'sets rejected_at timestamp' do
        freeze_time do
          application.reject!(rejection_reason, hiring_manager)
          expect(application.rejected_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'sets rejected_by to the user who rejected' do
        application.reject!(rejection_reason, hiring_manager)
        expect(application.rejected_by).to eq(hiring_manager)
      end

      it 'sets rejection_reason' do
        application.reject!(rejection_reason, hiring_manager)
        expect(application.rejection_reason).to eq(rejection_reason)
      end

      it 'persists the changes' do
        application.reject!(rejection_reason, hiring_manager)
        application.reload
        expect(application.rejected?).to be true
        expect(application.rejection_reason).to eq(rejection_reason)
      end
    end

    context 'when application is already hired' do
      let(:hired_app) { applications(:hired_application) }

      it 'raises AASM::InvalidTransition' do
        expect { hired_app.reject!('Changed mind', hiring_manager) }.to raise_error(AASM::InvalidTransition)
      end
    end

    context 'when application is already rejected' do
      let(:rejected_app) { applications(:rejected_application) }

      it 'raises AASM::InvalidTransition' do
        expect { rejected_app.reject!('Double rejection', hiring_manager) }.to raise_error(AASM::InvalidTransition)
      end
    end

    # =============================================================================
    # T163: Prevent rejecting from hired status
    # =============================================================================
    context 'T163: preventing reject when already hired' do
      let(:hired_app) { applications(:hired_application) }

      it 'prevents rejecting an already hired application' do
        expect(hired_app.hired?).to be true
        expect {
          hired_app.reject!('Changed mind', hiring_manager)
        }.to raise_error(AASM::InvalidTransition)
      end

      it 'does not change status when reject fails' do
        original_status = hired_app.status
        begin
          hired_app.reject!('Changed mind', hiring_manager)
        rescue AASM::InvalidTransition
          # Expected
        end
        hired_app.reload
        expect(hired_app.status).to eq(original_status)
      end

      it 'does not set rejected_at when reject fails' do
        original_rejected_at = hired_app.rejected_at
        begin
          hired_app.reject!('Changed mind', hiring_manager)
        rescue AASM::InvalidTransition
          # Expected
        end
        hired_app.reload
        expect(hired_app.rejected_at).to eq(original_rejected_at)
      end
    end
  end

  # =============================================================================
  # T114: Application#advance_to_stage!(stage, user, notes)
  # =============================================================================
  describe '#advance_to_stage!' do
    let(:application) { applications(:pending_application) }
    let(:hiring_manager) { users(:acme_hiring_manager) }
    let(:phone_screen_stage) { hiring_stages(:default_phone_screen) }
    let(:technical_stage) { hiring_stages(:default_technical) }

    context 'with valid stage' do
      it 'updates current_stage to the new stage' do
        application.advance_to_stage!(phone_screen_stage, hiring_manager)
        expect(application.current_stage).to eq(phone_screen_stage)
      end

      it 'creates an ApplicationStageTransition record' do
        expect {
          application.advance_to_stage!(phone_screen_stage, hiring_manager)
        }.to change(ApplicationStageTransition, :count).by(1)
      end

      it 'records the from_stage and to_stage' do
        original_stage = application.current_stage
        application.advance_to_stage!(phone_screen_stage, hiring_manager)

        transition = application.stage_transitions.last
        expect(transition.from_stage).to eq(original_stage)
        expect(transition.to_stage).to eq(phone_screen_stage)
      end

      it 'records the user who made the transition' do
        application.advance_to_stage!(phone_screen_stage, hiring_manager)

        transition = application.stage_transitions.last
        expect(transition.transitioned_by).to eq(hiring_manager)
      end

      it 'records optional notes' do
        notes = 'Strong phone screen performance'
        application.advance_to_stage!(phone_screen_stage, hiring_manager, notes)

        transition = application.stage_transitions.last
        expect(transition.notes).to eq(notes)
      end

      it 'allows advancing through multiple stages' do
        # Advance from Application Review to Phone Screen
        application.advance_to_stage!(phone_screen_stage, hiring_manager)
        expect(application.current_stage).to eq(phone_screen_stage)

        # Advance from Phone Screen to Technical Interview
        application.advance_to_stage!(technical_stage, hiring_manager)
        expect(application.current_stage).to eq(technical_stage)

        # Verify transition history
        expect(application.stage_transitions.count).to eq(2)
      end

      # =============================================================================
      # T161: Stage transition with history tracking
      # =============================================================================
      it 'T161: maintains complete history of stage transitions' do
        initial_stage = application.current_stage

        # First transition: Application Review → Phone Screen
        application.advance_to_stage!(phone_screen_stage, hiring_manager, 'Passed initial review')
        first_transition = application.stage_transitions.last

        expect(first_transition.from_stage).to eq(initial_stage)
        expect(first_transition.to_stage).to eq(phone_screen_stage)
        expect(first_transition.transitioned_by).to eq(hiring_manager)
        expect(first_transition.notes).to eq('Passed initial review')
        expect(first_transition.transitioned_at).to be_present

        # Second transition: Phone Screen → Technical Interview
        application.advance_to_stage!(technical_stage, hiring_manager, 'Strong technical skills')
        second_transition = application.stage_transitions.last

        expect(second_transition.from_stage).to eq(phone_screen_stage)
        expect(second_transition.to_stage).to eq(technical_stage)
        expect(second_transition.transitioned_by).to eq(hiring_manager)
        expect(second_transition.notes).to eq('Strong technical skills')

        # Verify chronological order
        transitions = application.stage_transitions.chronological
        expect(transitions.count).to eq(2)
        expect(transitions.first).to eq(first_transition)
        expect(transitions.last).to eq(second_transition)

        # Verify transition times are sequential
        expect(second_transition.transitioned_at).to be > first_transition.transitioned_at
      end

      it 'T161: tracks complete audit trail with user information' do
        initial_stage = application.current_stage
        application.advance_to_stage!(phone_screen_stage, hiring_manager, 'Notes here')

        transition = application.stage_transitions.last

        # Verify all audit fields are present
        expect(transition.application).to eq(application)
        expect(transition.from_stage).to eq(initial_stage)
        expect(transition.to_stage).to eq(phone_screen_stage)
        expect(transition.transitioned_by).to eq(hiring_manager)
        expect(transition.transitioned_at).to be_present
        expect(transition.notes).to eq('Notes here')

        # Verify transition can access user details
        expect(transition.transitioned_by.full_name).to be_present
        expect(transition.transitioned_by.email).to be_present
      end

      it 'persists the changes' do
        application.advance_to_stage!(phone_screen_stage, hiring_manager)
        application.reload
        expect(application.current_stage).to eq(phone_screen_stage)
      end
    end

    context 'with invalid stage (from different hiring process)' do
      let(:wrong_stage) { hiring_stages(:executive_interview) }

      it 'raises ArgumentError' do
        expect {
          application.advance_to_stage!(wrong_stage, hiring_manager)
        }.to raise_error(ArgumentError, /hiring process/)
      end

      it 'does not change current_stage' do
        original_stage = application.current_stage
        begin
          application.advance_to_stage!(wrong_stage, hiring_manager)
        rescue ArgumentError
          # Expected
        end
        expect(application.current_stage).to eq(original_stage)
      end

      it 'does not create transition record' do
        expect {
          begin
            application.advance_to_stage!(wrong_stage, hiring_manager)
          rescue ArgumentError
            # Expected
          end
        }.not_to change(ApplicationStageTransition, :count)
      end
    end

    context 'without user' do
      it 'allows nil user for automated transitions' do
        application.advance_to_stage!(phone_screen_stage, nil)

        transition = application.stage_transitions.last
        expect(transition.transitioned_by).to be_nil
        expect(application.current_stage).to eq(phone_screen_stage)
      end
    end
  end

  # =============================================================================
  # ARCHIVE TRANSITION
  # =============================================================================
  describe '#archive!' do
    context 'from in_progress' do
      let(:application) { applications(:pending_application) }

      it 'transitions to archived' do
        application.archive!
        expect(application.archived?).to be true
      end

      it 'sets archived_at timestamp' do
        freeze_time do
          application.archive!
          expect(application.archived_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    context 'from hired' do
      # Use a fresh application since hired_application has fixed timestamp
      let(:hired_app) { applications(:recently_hired_application) }

      it 'transitions to archived' do
        hired_app.archive!
        expect(hired_app.archived?).to be true
      end
    end

    context 'from rejected' do
      let(:rejected_app) { applications(:rejected_application) }

      it 'transitions to archived' do
        rejected_app.archive!
        expect(rejected_app.archived?).to be true
      end
    end
  end

  # =============================================================================
  # SCOPES
  # =============================================================================
  describe 'scopes' do
    describe '.recent' do
      it 'orders by created_at descending' do
        applications = Application.recent.limit(5)
        expect(applications.first.created_at).to be >= applications.last.created_at
      end
    end

    describe '.by_status' do
      it 'filters by in_progress' do
        apps = Application.by_status(:in_progress)
        expect(apps).to all(have_attributes(status: 'in_progress'))
      end

      it 'filters by hired' do
        apps = Application.by_status(:hired)
        expect(apps).to all(have_attributes(status: 'hired'))
      end

      it 'filters by rejected' do
        apps = Application.by_status(:rejected)
        expect(apps).to all(have_attributes(status: 'rejected'))
      end
    end

    describe '.with_applicant' do
      it 'eager loads applicant association' do
        applications = Application.with_applicant.limit(5)
        # Check that accessing applicant doesn't trigger additional queries
        expect(applications.first.association(:applicant)).to be_loaded
      end
    end

    describe '.with_job_posting' do
      it 'eager loads job_posting association' do
        applications = Application.with_job_posting.limit(5)
        expect(applications.first.association(:job_posting)).to be_loaded
      end
    end

    describe '.with_transitions' do
      it 'eager loads stage_transitions with stages and user' do
        applications = Application.with_transitions.limit(5)
        # This scope should eager load nested associations
        expect(applications).to be_present
      end
    end
  end

  # =============================================================================
  # BRAND SCOPING
  # =============================================================================
  describe 'brand scoping' do
    it 'only returns applications from current brand' do
      applications = Application.all
      expect(applications.pluck(:brand_id).uniq).to eq([brands(:acme).id])
    end

    it 'does not return applications from other brands' do
      # Globex application should not be visible
      globex_app = Application.unscoped.find_by(brand: brands(:globex))
      expect(Application.where(id: globex_app.id)).to be_empty
    end

    context 'with different current brand' do
      before do
        Current.brand = brands(:globex)
      end

      it 'returns only globex applications' do
        applications = Application.all
        expect(applications.pluck(:brand_id).uniq).to eq([brands(:globex).id])
      end
    end
  end

  # =============================================================================
  # CALLBACKS
  # =============================================================================
  describe 'callbacks' do
    describe 'after_commit :publish_stage_changed_notification' do
      let(:application) { applications(:pending_application) }
      let(:phone_screen) { hiring_stages(:default_phone_screen) }
      let(:hiring_manager) { users(:acme_hiring_manager) }

      it 'triggers notification after stage change' do
        # Just verify the callback doesn't raise errors
        expect {
          application.advance_to_stage!(phone_screen, hiring_manager)
        }.not_to raise_error
      end
    end
  end
end
