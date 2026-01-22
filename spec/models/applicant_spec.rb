# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

RSpec.describe Applicant, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:brand) }
    it { is_expected.to have_many(:applications).dependent(:destroy) }
  end

  describe 'validations' do
    subject(:applicant) { applicants(:john_doe) }

    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:email) }

    it do
      expect(applicant).to validate_uniqueness_of(:email)
        .scoped_to(:brand_id)
        .with_message('has already applied (duplicate applicant in this brand)')
    end

    it 'validates email format' do
      invalid = Applicant.new(
        brand: brands(:acme),
        first_name: 'Jamie',
        last_name: 'Taylor',
        email: 'invalid-email'
      )

      expect(invalid).not_to be_valid
      expect(invalid.errors[:email]).to include('must be a valid email address')
    end

    it 'allows blank phone' do
      no_phone = Applicant.new(
        brand: brands(:acme),
        first_name: 'Pat',
        last_name: 'NoPhone',
        email: 'pat.nophone+new@example.com',
        phone: nil
      )

      expect(no_phone).to be_valid
    end

    it 'rejects invalid phone format' do
      invalid_phone = Applicant.new(
        brand: brands(:acme),
        first_name: 'Sam',
        last_name: 'BadPhone',
        email: 'sam.badphone@example.com',
        phone: 'abc-def'
      )

      expect(invalid_phone).not_to be_valid
      expect(invalid_phone.errors[:phone]).to include('must be a valid phone number')
    end
  end

  describe '#full_name' do
    it 'combines first and last name' do
      applicant = applicants(:jane_smith)
      expect(applicant.full_name).to eq('Jane Smith')
    end
  end

  describe 'scopes' do
    describe '.recent' do
      it 'orders by created_at descending' do
        recent = Applicant.recent.limit(3).map(&:id)
        expect(recent.first).to eq(applicants(:recent_applicant).id)
      end
    end

    describe '.flagged' do
      it 'returns only flagged applicants' do
        flagged = Applicant.flagged
        expect(flagged).to include(applicants(:flagged_applicant))
        expect(flagged).not_to include(applicants(:john_doe))
      end
    end

    describe '.by_source' do
      it 'filters by source' do
        linkedin = Applicant.by_source('linkedin')
        expect(linkedin).to include(applicants(:john_doe))
        expect(linkedin).not_to include(applicants(:flagged_applicant))
      end
    end
  end

  describe 'resume validation' do
    let(:applicant) do
      Applicant.new(
        brand: brands(:acme),
        first_name: 'Jamie',
        last_name: 'Taylor',
        email: 'jamie.taylor@example.com'
      )
    end

    def attach_resume(record, filename:, content_type:, content:)
      record.resume.attach(
        io: StringIO.new(content),
        filename: filename,
        content_type: content_type
      )
    end

    it 'allows a valid resume attachment' do
      attach_resume(
        applicant,
        filename: 'resume.pdf',
        content_type: 'application/pdf',
        content: '%PDF-1.4 sample content'
      )

      expect(applicant).to be_valid
      expect(applicant.resume).to be_attached
    end

    it 'rejects an invalid resume attachment' do
      attach_resume(
        applicant,
        filename: 'resume.txt',
        content_type: 'text/plain',
        content: 'plain text resume'
      )

      expect(applicant).not_to be_valid
      expect(applicant.errors[:resume]).to include('must be a PDF, DOC, or DOCX file')
    end

    it 'rejects a resume over 5MB' do
      attach_resume(
        applicant,
        filename: 'resume.pdf',
        content_type: 'application/pdf',
        content: 'a' * (5.megabytes + 1)
      )

      expect(applicant).not_to be_valid
      expect(applicant.errors[:resume]).to include('must be less than 5MB')
    end
  end
end
