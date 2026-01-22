# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:brand) }
    it { is_expected.to have_many(:location_assignments).dependent(:destroy) }
    it { is_expected.to have_many(:locations).through(:location_assignments) }
  end

  describe 'validations' do
    subject(:user) { users(:acme_admin) }

    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:role) }

    it 'validates email uniqueness within a brand (case-insensitive)' do
      existing = users(:acme_interviewer)

      same_brand = User.new(
        brand: existing.brand,
        email: existing.email.upcase,
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'Case',
        last_name: 'Conflict',
        role: :admin
      )

      expect(same_brand).not_to be_valid
      expect(same_brand.errors[:email]).to include('has already been taken')

      different_brand = User.new(
        brand: brands(:globex),
        email: existing.email.upcase,
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'Cross',
        last_name: 'Brand',
        role: :admin
      )

      # email should be unique
      expect(different_brand).not_to be_valid
      expect(different_brand.errors[:email]).to include('has already been taken')
    end
  end

  describe '#full_name' do
    it 'combines first and last name' do
      user = users(:acme_admin)
      expect(user.full_name).to eq('Alice Admin')
    end
  end

  describe 'authorization helpers' do
    let(:application) { applications(:pending_application) }
    let(:globex_application) { applications(:globex_application) }
    let(:job_posting) { job_postings(:backend_engineer_published) }
    let(:globex_posting) { job_postings(:globex_engineer_published) }

    describe '#can_manage_application?' do
      it 'allows super admins to manage any application' do
        user = users(:super_admin)
        expect(user.can_manage_application?(application)).to be(true)
        expect(user.can_manage_application?(globex_application)).to be(true)
      end

      it 'allows admins to manage any application within the brand' do
        user = users(:acme_admin)
        expect(user.can_manage_application?(application)).to be(true)
      end

      it 'allows hiring managers assigned to the application location' do
        user = users(:acme_hiring_manager)
        expect(user.can_manage_application?(application)).to be(true)
      end

      it 'denies hiring managers not assigned to the application location' do
        user = users(:acme_hiring_manager)
        expect(user.can_manage_application?(globex_application)).to be(false)
      end

      it 'denies interviewers' do
        user = users(:acme_interviewer)
        expect(user.can_manage_application?(application)).to be(false)
      end
    end

    describe '#can_schedule_interview?' do
      it 'allows admins and super admins' do
        expect(users(:super_admin).can_schedule_interview?(application)).to be(true)
        expect(users(:acme_admin).can_schedule_interview?(application)).to be(true)
      end

      it 'allows hiring managers assigned to the application location' do
        user = users(:acme_hiring_manager)
        expect(user.can_schedule_interview?(application)).to be(true)
      end

      it 'denies hiring managers not assigned to the application location' do
        user = users(:acme_hiring_manager)
        expect(user.can_schedule_interview?(globex_application)).to be(false)
      end

      it 'denies interviewers' do
        user = users(:acme_interviewer)
        expect(user.can_schedule_interview?(application)).to be(false)
      end
    end

    describe '#can_publish_job_posting?' do
      it 'allows admins and super admins' do
        expect(users(:super_admin).can_publish_job_posting?(job_posting)).to be(true)
        expect(users(:acme_admin).can_publish_job_posting?(job_posting)).to be(true)
      end

      it 'allows hiring managers assigned to the job posting location' do
        user = users(:acme_hiring_manager)
        expect(user.can_publish_job_posting?(job_posting)).to be(true)
      end

      it 'denies hiring managers not assigned to the job posting location' do
        user = users(:acme_hiring_manager)
        expect(user.can_publish_job_posting?(globex_posting)).to be(false)
      end

      it 'denies interviewers' do
        user = users(:acme_interviewer)
        expect(user.can_publish_job_posting?(job_posting)).to be(false)
      end
    end
  end
end
