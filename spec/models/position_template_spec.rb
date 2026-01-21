# PositionTemplate Model Spec - DHH/37signals Testing Style
#
# TESTING PHILOSOPHY:
# - Test behavior, not implementation
# - Use fixtures for realistic, stable test data
# - Focus on validations, associations, scopes, and business logic
# - Keep tests simple and readable
#
# FIXTURE USAGE:
# - position_templates(:software_engineer) - Active engineering template
# - position_templates(:marketing_manager_draft) - Draft template
# - position_templates(:finance_analyst_globex) - Different brand (for scoping tests)
#
# T046: Validation tests
# T047: Scope tests
# T048: Deletion prevention tests

require 'rails_helper'

RSpec.describe PositionTemplate, type: :model do
  # SETUP: Use fixtures for all tests
  # WHY FIXTURES: Realistic data shared across tests, less setup code
  fixtures :brands, :position_templates

  # =============================================================================
  # T046: VALIDATIONS
  # =============================================================================
  # PURPOSE: Ensure data integrity - all required fields must be present
  # WHY: Prevent invalid templates from being saved to database

  describe 'validations' do
    # TEST: Valid template passes all validations
    # EXPECTATION: software_engineer fixture should be valid
    context 'with valid attributes' do
      it 'is valid with all required fields' do
        template = position_templates(:software_engineer)
        expect(template).to be_valid
      end
    end

    # TEST: name is required
    # EXPECTATION: Template without name should fail validation
    context 'when name is missing' do
      it 'is invalid without a name' do
        template = PositionTemplate.new(
          brand: brands(:acme),
          job_title: 'Senior Engineer',
          category: 'Engineering',
          department: 'Product'
        )
        expect(template).not_to be_valid
        expect(template.errors[:name]).to include("can't be blank")
      end
    end

    # TEST: job_title is required
    # EXPECTATION: Template without job_title should fail validation
    context 'when job_title is missing' do
      it 'is invalid without a job_title' do
        template = PositionTemplate.new(
          brand: brands(:acme),
          name: 'Engineer Template',
          category: 'Engineering',
          department: 'Product'
        )
        expect(template).not_to be_valid
        expect(template.errors[:job_title]).to include("can't be blank")
      end
    end

    # TEST: category is required
    # EXPECTATION: Template without category should fail validation
    context 'when category is missing' do
      it 'is invalid without a category' do
        template = PositionTemplate.new(
          brand: brands(:acme),
          name: 'Engineer Template',
          job_title: 'Senior Engineer',
          department: 'Product'
        )
        expect(template).not_to be_valid
        expect(template.errors[:category]).to include("can't be blank")
      end
    end

    # TEST: department is required
    # EXPECTATION: Template without department should fail validation
    context 'when department is missing' do
      it 'is invalid without a department' do
        template = PositionTemplate.new(
          brand: brands(:acme),
          name: 'Engineer Template',
          job_title: 'Senior Engineer',
          category: 'Engineering'
        )
        expect(template).not_to be_valid
        expect(template.errors[:department]).to include("can't be blank")
      end
    end

    # TEST: Optional fields can be nil
    # EXPECTATION: minimal_template fixture has nil requirements and education_requirement
    context 'with optional fields' do
      it 'is valid with nil requirements and education_requirement' do
        template = position_templates(:minimal_template)
        expect(template.requirements).to be_nil
        expect(template.education_requirement).to be_nil
        expect(template).to be_valid
      end
    end
  end

  # =============================================================================
  # ASSOCIATIONS
  # =============================================================================
  # PURPOSE: Verify relationships between models
  # WHY: Ensure database foreign keys and ActiveRecord associations work correctly

  describe 'associations' do
    # TEST: Template belongs to a brand
    # EXPECTATION: Every template must have a brand (multi-tenant requirement)
    it 'belongs to a brand' do
      template = position_templates(:software_engineer)
      expect(template.brand).to eq(brands(:acme))
      expect(template.brand).to be_a(Brand)
    end

    # TEST: Template has many job_postings
    # EXPECTATION: Association exists (even if empty for test templates)
    # NOTE: The dependent: :restrict_with_error option is tested in T048
    it 'has many job_postings' do
      template = position_templates(:software_engineer)
      expect(template).to respond_to(:job_postings)
    end
  end

  # =============================================================================
  # T047: SCOPES
  # =============================================================================
  # PURPOSE: Test query scopes for filtering templates
  # WHY: Scopes are used throughout the application to filter data efficiently

  describe 'scopes' do
    # TEST: .active scope returns only active templates
    # EXPECTATION: Should include software_engineer, sales_rep, customer_support
    #              Should exclude marketing_manager_draft (status: draft)
    describe '.active' do
      it 'returns only templates with active status' do
        # Setup: We have 3 active templates and 1 draft in fixtures
        active_templates = PositionTemplate.active

        # Should include active templates
        expect(active_templates).to include(position_templates(:software_engineer))
        expect(active_templates).to include(position_templates(:sales_rep))
        expect(active_templates).to include(position_templates(:customer_support))

        # Should NOT include draft templates
        expect(active_templates).not_to include(position_templates(:marketing_manager_draft))
      end
    end

    # TEST: .by_category scope filters by category
    # EXPECTATION: Filtering by 'Engineering' should return software_engineer only
    describe '.by_category' do
      it 'returns templates matching the specified category' do
        engineering_templates = PositionTemplate.by_category('Engineering')

        expect(engineering_templates).to include(position_templates(:software_engineer))
        expect(engineering_templates).not_to include(position_templates(:sales_rep))
        expect(engineering_templates).not_to include(position_templates(:customer_support))
      end

      it 'returns templates for Sales category' do
        sales_templates = PositionTemplate.by_category('Sales')

        expect(sales_templates).to include(position_templates(:sales_rep))
        expect(sales_templates).not_to include(position_templates(:software_engineer))
      end
    end

    # TEST: .recent scope orders by created_at descending
    # EXPECTATION: Most recently created templates appear first
    # ORDER: customer_support (10d ago) > marketing_manager_draft (5d ago) > minimal_template (2d ago)
    describe '.recent' do
      it 'returns templates ordered by created_at descending' do
        recent_templates = PositionTemplate.recent.limit(3)

        # Most recent template should be first
        expect(recent_templates.first).to eq(position_templates(:minimal_template))

        # Verify ordering is by created_at descending
        created_at_values = recent_templates.map(&:created_at)
        expect(created_at_values).to eq(created_at_values.sort.reverse)
      end
    end

    # TEST: Scope chaining works correctly
    # EXPECTATION: Can combine .active.by_category.recent
    describe 'scope chaining' do
      it 'allows chaining multiple scopes together' do
        # Find active Engineering templates, ordered by most recent
        templates = PositionTemplate.active.by_category('Engineering').recent

        expect(templates).to include(position_templates(:software_engineer))
        expect(templates.count).to eq(1)
      end
    end
  end

  # =============================================================================
  # ENUMS
  # =============================================================================
  # PURPOSE: Test status enum functionality
  # WHY: Ensure status values and helper methods work correctly

  describe 'enums' do
    # TEST: status enum has correct values
    # EXPECTATION: draft: 0, active: 1
    describe 'status' do
      it 'defines draft and active statuses' do
        template = position_templates(:software_engineer)

        # Test enum values
        expect(PositionTemplate.statuses).to eq({ 'draft' => 0, 'active' => 1 })
      end

      it 'provides status query methods' do
        active_template = position_templates(:software_engineer)
        draft_template = position_templates(:marketing_manager_draft)

        # Test status_* query methods
        expect(active_template.status_active?).to be true
        expect(active_template.status_draft?).to be false

        expect(draft_template.status_draft?).to be true
        expect(draft_template.status_active?).to be false
      end

      it 'allows updating status' do
        template = position_templates(:marketing_manager_draft)
        expect(template.status_draft?).to be true

        template.update(status: :active)
        expect(template.status_active?).to be true
      end
    end
  end

  # =============================================================================
  # T048: DELETION PREVENTION
  # =============================================================================
  # PURPOSE: Test that templates with job_postings cannot be deleted
  # WHY: Data integrity - prevent orphaned job_postings
  # IMPLEMENTATION: dependent: :restrict_with_error on has_many :job_postings

  describe 'deletion prevention' do
    # TEST: Template with job_postings cannot be deleted
    # EXPECTATION: destroy! raises error, template remains in database
    context 'when template has associated job_postings' do
      it 'prevents deletion and raises an error' do
        # Setup: Create a template with a job_posting
        template = position_templates(:software_engineer)

        # Create a job_posting associated with this template
        # NOTE: This requires job_posting fixtures or factory
        # For now, we'll create it manually
        job_posting = JobPosting.create!(
          brand: brands(:acme),
          position_template: template,
          title: 'Backend Engineer',
          status: :draft
        )

        # Attempt to destroy template
        expect { template.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)

        # Verify template still exists
        expect(PositionTemplate.exists?(template.id)).to be true
      end
    end

    # TEST: Template without job_postings can be deleted
    # EXPECTATION: destroy! succeeds, template removed from database
    context 'when template has no associated job_postings' do
      it 'allows deletion' do
        template = position_templates(:minimal_template)

        # Verify no job_postings exist
        expect(template.job_postings.count).to eq(0)

        # Destroy should succeed
        expect { template.destroy! }.not_to raise_error

        # Verify template is deleted
        expect(PositionTemplate.exists?(template.id)).to be false
      end
    end
  end

  # =============================================================================
  # BRAND SCOPING (via BrandScoped concern)
  # =============================================================================
  # PURPOSE: Test multi-tenant data isolation
  # WHY: Security - users must only see data from their brand
  # NOTE: Full integration testing happens in request specs with authenticated users

  describe 'brand scoping' do
    # TEST: Templates are scoped to their brand
    # EXPECTATION: Acme templates != Globex templates
    it 'isolates templates by brand' do
      acme_templates = PositionTemplate.where(brand: brands(:acme))
      globex_templates = PositionTemplate.where(brand: brands(:globex))

      # Acme has 5 templates
      expect(acme_templates.count).to eq(5)

      # Globex has 1 template
      expect(globex_templates.count).to eq(1)

      # finance_analyst_globex belongs to Globex, not Acme
      expect(acme_templates).not_to include(position_templates(:finance_analyst_globex))
      expect(globex_templates).to include(position_templates(:finance_analyst_globex))
    end
  end

  # =============================================================================
  # CACHE INVALIDATION
  # =============================================================================
  # PURPOSE: Test Redis cache invalidation on create/update/destroy
  # WHY: Ensure active_cached scope returns fresh data
  # IMPLEMENTATION: after_commit :invalidate_active_cache

  describe 'cache invalidation' do
    # TEST: Cache is invalidated after creating a template
    # EXPECTATION: Rails.cache.delete called with correct key
    it 'invalidates active cache after create' do
      # Setup: Set Current.brand for cache key
      Current.brand = brands(:acme)

      # Expect cache deletion on create
      expect(Rails.cache).to receive(:delete).with("position_templates/active/#{brands(:acme).id}")

      PositionTemplate.create!(
        brand: brands(:acme),
        name: 'New Template',
        job_title: 'New Position',
        category: 'Engineering',
        department: 'Product'
      )
    end

    # TEST: Cache is invalidated after updating a template
    # EXPECTATION: Rails.cache.delete called with correct key
    it 'invalidates active cache after update' do
      template = position_templates(:software_engineer)

      expect(Rails.cache).to receive(:delete).with("position_templates/active/#{template.brand_id}")

      template.update!(name: 'Updated Template Name')
    end

    # TEST: Cache is invalidated after destroying a template
    # EXPECTATION: Rails.cache.delete called with correct key
    it 'invalidates active cache after destroy' do
      template = position_templates(:minimal_template)

      expect(Rails.cache).to receive(:delete).with("position_templates/active/#{template.brand_id}")

      template.destroy!
    end
  end
end
