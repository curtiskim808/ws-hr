# JobPosting Model Spec - T075, T076
#
# TESTING PHILOSOPHY:
# - Test behavior, not implementation
# - Use fixtures for realistic, stable test data
# - Focus on validations, associations, scopes, state machine, and business logic
# - Keep tests simple and readable
#
# FIXTURE USAGE:
# - job_postings(:backend_engineer_published) - Published posting
# - job_postings(:marketing_manager_draft) - Draft posting
# - job_postings(:devops_engineer_link_only) - Link-only posting
# - job_postings(:data_analyst_unpublished) - Unpublished posting
# - job_postings(:globex_engineer_published) - Different brand (for scoping tests)
#
# T075: AASM state machine transition tests
# T076: Validation and business logic tests

require 'rails_helper'

RSpec.describe JobPosting, type: :model do
  # SETUP: Use fixtures for all tests
  # WHY FIXTURES: Realistic data shared across tests, less setup code
  fixtures :brands, :locations, :position_templates, :hiring_processes, :hiring_stages, :job_postings

  # =============================================================================
  # T076: VALIDATIONS
  # =============================================================================
  # PURPOSE: Ensure data integrity - all required fields must be present
  # WHY: Prevent invalid job postings from being saved to database

  describe 'validations' do
    # TEST: Valid job posting passes all validations
    # EXPECTATION: backend_engineer_published fixture should be valid
    context 'with valid attributes' do
      it 'is valid with all required fields' do
        posting = job_postings(:backend_engineer_published)
        expect(posting).to be_valid
      end
    end

    # TEST: position_template is required
    # EXPECTATION: Posting without template should fail validation
    context 'when position_template is missing' do
      it 'is invalid without a position_template' do
        posting = JobPosting.new(
          brand: brands(:acme),
          location: locations(:acme_hq),
          hiring_process: hiring_processes(:default_process),
          job_title: 'Senior Engineer',
          description: 'Test description'
        )
        expect(posting).not_to be_valid
        expect(posting.errors[:position_template]).to include("must exist")
      end
    end

    # TEST: location is required
    # EXPECTATION: Posting without location should fail validation
    context 'when location is missing' do
      it 'is invalid without a location' do
        posting = JobPosting.new(
          brand: brands(:acme),
          position_template: position_templates(:software_engineer),
          hiring_process: hiring_processes(:default_process),
          job_title: 'Senior Engineer',
          description: 'Test description'
        )
        expect(posting).not_to be_valid
        expect(posting.errors[:location]).to include("must exist")
      end
    end

    # TEST: hiring_process is required before publishing
    # EXPECTATION: Cannot publish without hiring_process
    context 'when publishing without hiring_process' do
      it 'prevents publishing if hiring_process is missing' do
        posting = job_postings(:marketing_manager_draft)
        posting.hiring_process = nil

        expect { posting.publish! }.to raise_error(AASM::InvalidTransition)
        expect(posting.status).to eq('draft')
      end
    end
  end

  # =============================================================================
  # T075: AASM STATE MACHINE - STATES
  # =============================================================================
  # PURPOSE: Test state machine configuration and initial state
  # WHY: Ensure AASM is properly configured with correct states

  describe 'state machine states' do
    # TEST: Initial state is draft
    # EXPECTATION: New postings start in draft status
    it 'has initial state of draft' do
      posting = JobPosting.new(
        brand: brands(:acme),
        position_template: position_templates(:software_engineer),
        location: locations(:acme_hq),
        hiring_process: hiring_processes(:default_process),
        job_title: 'Test Position',
        description: 'Test description',
        requirements: 'Test requirements'
      )
      expect(posting.status).to eq('draft')
      expect(posting.draft?).to be true
    end

    # TEST: All states are defined
    # EXPECTATION: AASM defines draft, published, link_only, unpublished
    it 'defines all expected states' do
      expect(JobPosting.aasm.states.map(&:name)).to contain_exactly(
        :draft, :published, :link_only, :unpublished
      )
    end

    # TEST: State query methods work
    # EXPECTATION: Enum-generated methods (draft?, published?, etc.) work correctly
    it 'provides state query methods' do
      draft = job_postings(:marketing_manager_draft)
      published = job_postings(:backend_engineer_published)
      link_only = job_postings(:devops_engineer_link_only)
      unpublished = job_postings(:data_analyst_unpublished)

      expect(draft.draft?).to be true
      expect(published.published?).to be true
      expect(link_only.link_only?).to be true
      expect(unpublished.unpublished?).to be true
    end
  end

  # =============================================================================
  # T075: AASM STATE MACHINE - TRANSITIONS (publish!)
  # =============================================================================
  # PURPOSE: Test publish! event transitions and callbacks
  # WHY: Ensure postings can be published and timestamps are recorded

  describe 'state transitions - publish!' do
    # TEST: Transition from draft to published
    # EXPECTATION: draft → published transition succeeds
    context 'from draft to published' do
      it 'transitions from draft to published' do
        posting = job_postings(:marketing_manager_draft)
        expect(posting.status).to eq('draft')

        posting.publish!

        expect(posting.status).to eq('published')
        expect(posting.published?).to be true
      end

      it 'sets published_at timestamp' do
        posting = job_postings(:marketing_manager_draft)
        expect(posting.published_at).to be_nil

        posting.publish!

        expect(posting.published_at).to be_present
        expect(posting.published_at).to be_within(1.second).of(Time.current)
      end

    end

    # TEST: Transition from link_only to published
    # EXPECTATION: link_only → published transition succeeds
    context 'from link_only to published' do
      it 'transitions from link_only to published' do
        posting = job_postings(:devops_engineer_link_only)
        expect(posting.status).to eq('link_only')

        posting.publish!

        expect(posting.status).to eq('published')
        expect(posting.published?).to be true
      end

      it 'updates published_at timestamp' do
        posting = job_postings(:devops_engineer_link_only)
        old_published_at = posting.published_at
        posting.publish!

        expect(posting.published_at).to eq(old_published_at)
      end
    end

    # TEST: Guard condition - requires hiring_process
    # EXPECTATION: Cannot publish without hiring_process
    context 'when hiring_process is missing' do
      it 'prevents transition if hiring_process is nil' do
        posting = job_postings(:marketing_manager_draft)
        posting.hiring_process = nil

        expect { posting.publish! }.to raise_error(AASM::InvalidTransition)
        expect(posting.status).to eq('draft')
      end
    end

    # TEST: Invalid transition from unpublished
    # EXPECTATION: Cannot publish from unpublished state
    context 'from unpublished (invalid)' do
      it 'raises error for invalid transition' do
        posting = job_postings(:data_analyst_unpublished)
        expect(posting.status).to eq('unpublished')

        expect { posting.publish! }.to raise_error(AASM::InvalidTransition)
        expect(posting.status).to eq('unpublished')
      end
    end
  end

  # =============================================================================
  # T075: AASM STATE MACHINE - TRANSITIONS (unpublish!)
  # =============================================================================
  # PURPOSE: Test unpublish! event transitions and callbacks
  # WHY: Ensure postings can be unpublished and timestamps are recorded

  describe 'state transitions - unpublish!' do
    # TEST: Transition from published to unpublished
    # EXPECTATION: published → unpublished transition succeeds
    context 'from published to unpublished' do
      it 'transitions from published to unpublished' do
        posting = job_postings(:backend_engineer_published)
        expect(posting.status).to eq('published')

        posting.unpublish!

        expect(posting.status).to eq('unpublished')
        expect(posting.unpublished?).to be true
      end

      it 'sets unpublished_at timestamp' do
        posting = job_postings(:backend_engineer_published)
        expect(posting.unpublished_at).to be_nil

        posting.unpublish!

        expect(posting.unpublished_at).to be_present
        expect(posting.unpublished_at).to be_within(1.second).of(Time.current)
      end
    end

    # TEST: Transition from link_only to unpublished
    # EXPECTATION: link_only → unpublished transition succeeds
    context 'from link_only to unpublished' do
      it 'transitions from link_only to unpublished' do
        posting = job_postings(:devops_engineer_link_only)
        expect(posting.status).to eq('link_only')

        posting.unpublish!

        expect(posting.status).to eq('unpublished')
        expect(posting.unpublished?).to be true
      end

      it 'sets unpublished_at timestamp' do
        posting = job_postings(:devops_engineer_link_only)

        posting.unpublish!

        expect(posting.unpublished_at).to be_present
      end
    end

    # TEST: Invalid transition from draft
    # EXPECTATION: Cannot unpublish from draft state
    context 'from draft (invalid)' do
      it 'raises error for invalid transition' do
        posting = job_postings(:marketing_manager_draft)
        expect(posting.status).to eq('draft')

        expect { posting.unpublish! }.to raise_error(AASM::InvalidTransition)
        expect(posting.status).to eq('draft')
      end
    end
  end

  # =============================================================================
  # T075: AASM STATE MACHINE - TRANSITIONS (make_link_only!)
  # =============================================================================
  # PURPOSE: Test make_link_only! event transitions
  # WHY: Ensure postings can be changed to link-only access

  describe 'state transitions - make_link_only!' do
    # TEST: Transition from published to link_only
    # EXPECTATION: published → link_only transition succeeds
    context 'from published to link_only' do
      it 'transitions from published to link_only' do
        posting = job_postings(:backend_engineer_published)
        expect(posting.status).to eq('published')

        posting.make_link_only!

        expect(posting.status).to eq('link_only')
        expect(posting.link_only?).to be true
      end

      it 'preserves published_at timestamp' do
        posting = job_postings(:backend_engineer_published)
        published_at = posting.published_at

        posting.make_link_only!

        expect(posting.published_at).to eq(published_at)
      end
    end

    # TEST: Invalid transition from draft
    # EXPECTATION: Cannot make draft posting link-only
    context 'from draft (invalid)' do
      it 'raises error for invalid transition' do
        posting = job_postings(:marketing_manager_draft)
        expect(posting.status).to eq('draft')

        expect { posting.make_link_only! }.to raise_error(AASM::InvalidTransition)
        expect(posting.status).to eq('draft')
      end
    end

    # TEST: Invalid transition from unpublished
    # EXPECTATION: Cannot make unpublished posting link-only
    context 'from unpublished (invalid)' do
      it 'raises error for invalid transition' do
        posting = job_postings(:data_analyst_unpublished)
        expect(posting.status).to eq('unpublished')

        expect { posting.make_link_only! }.to raise_error(AASM::InvalidTransition)
        expect(posting.status).to eq('unpublished')
      end
    end
  end

  # =============================================================================
  # T075: STATE MACHINE - COMPLETE TRANSITION MATRIX
  # =============================================================================
  # PURPOSE: Test all valid and invalid transitions comprehensively
  # WHY: Ensure state machine is configured correctly
  # NOTE: Each transition is tested in isolation to avoid state mutations affecting other tests

  describe 'transition matrix' do
    # Valid transitions - each tested in isolation
    describe 'valid transitions' do
      it 'allows draft to published' do
        posting = job_postings(:marketing_manager_draft)
        expect { posting.publish! }.not_to raise_error
        expect(posting.status).to eq('published')
      end

      it 'allows published to link_only' do
        posting = job_postings(:backend_engineer_published)
        expect { posting.make_link_only! }.not_to raise_error
        expect(posting.status).to eq('link_only')
      end

      it 'allows published to unpublished' do
        posting = job_postings(:backend_engineer_published)
        expect { posting.unpublish! }.not_to raise_error
        expect(posting.status).to eq('unpublished')
      end

      it 'allows link_only to published' do
        posting = job_postings(:devops_engineer_link_only)
        expect { posting.publish! }.not_to raise_error
        expect(posting.status).to eq('published')
      end

      it 'allows link_only to unpublished' do
        posting = job_postings(:devops_engineer_link_only)
        expect { posting.unpublish! }.not_to raise_error
        expect(posting.status).to eq('unpublished')
      end
    end

    # Invalid transitions - each tested in isolation
    describe 'invalid transitions' do
      it 'blocks draft to unpublished' do
        posting = job_postings(:marketing_manager_draft)
        expect { posting.unpublish! }.to raise_error(AASM::InvalidTransition)
        expect(posting.status).to eq('draft')
      end

      it 'blocks draft to link_only' do
        posting = job_postings(:marketing_manager_draft)
        expect { posting.make_link_only! }.to raise_error(AASM::InvalidTransition)
        expect(posting.status).to eq('draft')
      end

      it 'blocks unpublished to published' do
        posting = job_postings(:data_analyst_unpublished)
        expect { posting.publish! }.to raise_error(AASM::InvalidTransition)
        expect(posting.status).to eq('unpublished')
      end

      it 'blocks unpublished to link_only' do
        posting = job_postings(:data_analyst_unpublished)
        expect { posting.make_link_only! }.to raise_error(AASM::InvalidTransition)
        expect(posting.status).to eq('unpublished')
      end
    end
  end

  # =============================================================================
  # T076: SCOPES
  # =============================================================================
  # PURPOSE: Test query scopes for filtering job postings
  # WHY: Ensure scopes return correct filtered results

  describe 'scopes' do
    # TEST: published scope
    # EXPECTATION: Returns only published postings
    describe '.published' do
      it 'returns only published job postings' do
        published_postings = JobPosting.published

        expect(published_postings).to include(job_postings(:backend_engineer_published))
        expect(published_postings).to include(job_postings(:sales_rep_published))
        expect(published_postings).to include(job_postings(:customer_support_published))
        expect(published_postings).not_to include(job_postings(:marketing_manager_draft))
        expect(published_postings).not_to include(job_postings(:devops_engineer_link_only))
        expect(published_postings).not_to include(job_postings(:data_analyst_unpublished))
      end
    end

    # TEST: at_location scope
    # EXPECTATION: Returns postings at specified location
    describe '.at_location' do
      it 'returns postings at specified location' do
        hq_postings = JobPosting.at_location(locations(:acme_hq).id)

        expect(hq_postings).to include(job_postings(:backend_engineer_published))
        expect(hq_postings).to include(job_postings(:customer_support_published))
        expect(hq_postings).not_to include(job_postings(:sales_rep_published)) # remote
      end
    end

    # TEST: recent scope
    # EXPECTATION: Returns postings ordered by published_at DESC
    # recent_posting (1d ago)
    # customer_support_published (5d ago)
    # backend_engineer_published (7d ago)    
    # sales_rep_published (14d ago)
    describe '.recent' do
      it 'orders postings by published_at descending' do
        recent_postings = JobPosting.published.recent.limit(3)

        # Most recent first
        expect(recent_postings.first).to eq(job_postings(:recent_posting))
        expect(recent_postings.second).to eq(job_postings(:customer_support_published))
        expect(recent_postings.third).to eq(job_postings(:backend_engineer_published))
      end
    end

    # TEST: Brand scoping (via BrandScoped concern)
    # EXPECTATION: Only returns postings from current brand
    describe 'brand scoping' do
      it 'only returns postings from current brand' do
        # Simulate Current.brand = acme
        allow(Current).to receive(:brand).and_return(brands(:acme))

        acme_postings = JobPosting.all

        expect(acme_postings).to include(job_postings(:backend_engineer_published))
        expect(acme_postings).not_to include(job_postings(:globex_engineer_published))
      end
    end
  end

  # =============================================================================
  # T076: BUSINESS LOGIC METHODS
  # =============================================================================
  # PURPOSE: Test computed attributes and helper methods
  # WHY: Ensure business logic calculations are correct

  describe 'business logic methods' do
    # TEST: days_since_published
    # EXPECTATION: Returns correct number of days since publication
    describe '#days_since_published' do
      it 'returns number of days since published_at' do
        posting = job_postings(:backend_engineer_published)
        expect(posting.days_since_published).to eq(7)
      end

      it 'returns nil if not published' do
        posting = job_postings(:marketing_manager_draft)
        expect(posting.days_since_published).to be_nil
      end
    end

    # TEST: accepting_applications?
    # EXPECTATION: Returns true for published and link_only, false otherwise
    describe '#accepting_applications?' do
      it 'returns true for published postings' do
        posting = job_postings(:backend_engineer_published)
        expect(posting.accepting_applications?).to be true
      end

      it 'returns true for link_only postings' do
        posting = job_postings(:devops_engineer_link_only)
        expect(posting.accepting_applications?).to be true
      end

      it 'returns false for draft postings' do
        posting = job_postings(:marketing_manager_draft)
        expect(posting.accepting_applications?).to be false
      end

      it 'returns false for unpublished postings' do
        posting = job_postings(:data_analyst_unpublished)
        expect(posting.accepting_applications?).to be false
      end
    end

    # TEST: visible_on_careers_page?
    # EXPECTATION: Returns true only for published postings
    describe '#visible_on_careers_page?' do
      it 'returns true for published postings' do
        posting = job_postings(:backend_engineer_published)
        expect(posting.visible_on_careers_page?).to be true
      end

      it 'returns false for link_only postings' do
        posting = job_postings(:devops_engineer_link_only)
        expect(posting.visible_on_careers_page?).to be false
      end

      it 'returns false for draft postings' do
        posting = job_postings(:marketing_manager_draft)
        expect(posting.visible_on_careers_page?).to be false
      end

      it 'returns false for unpublished postings' do
        posting = job_postings(:data_analyst_unpublished)
        expect(posting.visible_on_careers_page?).to be false
      end
    end
  end

  # =============================================================================
  # T076: AUTO-POPULATION FROM TEMPLATE
  # =============================================================================
  # PURPOSE: Test automatic copying of fields from position_template
  # WHY: Ensure job postings inherit template data on creation

  describe 'auto-population from template' do
    # TEST: Copy fields from template on create
    # EXPECTATION: job_title, description, requirements copied from template
    it 'copies job_title, description, requirements from position_template' do
      posting = JobPosting.create!(
        brand: brands(:acme),
        position_template: position_templates(:software_engineer),
        location: locations(:acme_hq),
        hiring_process: hiring_processes(:default_process)
      )

      expect(posting.job_title).to eq(position_templates(:software_engineer).job_title)
      expect(posting.description).to eq(position_templates(:software_engineer).description)
      expect(posting.requirements).to eq(position_templates(:software_engineer).requirements)
    end

    # TEST: Allow override of template fields
    # EXPECTATION: Explicitly provided fields override template
    it 'allows overriding template fields' do
      posting = JobPosting.create!(
        brand: brands(:acme),
        position_template: position_templates(:software_engineer),
        location: locations(:acme_hq),
        hiring_process: hiring_processes(:default_process),
        job_title: 'Custom Job Title'
      )

      expect(posting.job_title).to eq('Custom Job Title')
      expect(posting.job_title).not_to eq(position_templates(:software_engineer).job_title)
    end

    # TEST: Set default hiring_process
    # EXPECTATION: Uses brand's default process if not specified
    it 'sets default hiring_process if not provided' do
      posting = JobPosting.create!(
        brand: brands(:acme),
        position_template: position_templates(:software_engineer),
        location: locations(:acme_hq)
      )
      binding.pry
      expect(posting.hiring_process).to eq(hiring_processes(:default_process))
      expect(posting.hiring_process.is_default).to be true
    end
  end

  # =============================================================================
  # T076: ASSOCIATIONS
  # =============================================================================
  # PURPOSE: Test model associations
  # WHY: Ensure relationships work correctly

  describe 'associations' do
    it 'belongs to brand' do
      posting = job_postings(:backend_engineer_published)
      expect(posting.brand).to eq(brands(:acme))
    end

    it 'belongs to position_template' do
      posting = job_postings(:backend_engineer_published)
      expect(posting.position_template).to eq(position_templates(:software_engineer))
    end

    it 'belongs to location' do
      posting = job_postings(:backend_engineer_published)
      expect(posting.location).to eq(locations(:acme_hq))
    end

    it 'belongs to hiring_process' do
      posting = job_postings(:backend_engineer_published)
      expect(posting.hiring_process).to eq(hiring_processes(:default_process))
    end
  end
end
