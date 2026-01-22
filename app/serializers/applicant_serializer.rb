# ApplicantSerializer - JSON:API formatted serialization for applicants

class ApplicantSerializer
  include JSONAPI::Serializer

  attributes :first_name,
             :last_name,
             :email,
             :phone,
             :preferred_language,
             :source,
             :flagged,
             :flag_reason,
             :created_at,
             :updated_at


  attribute :full_name do |applicant|
    applicant.full_name
  end

  attribute :applications_count do |applicant|
    applicant.applications.count
  end

  attribute :resume_attached do |applicant|
    applicant.resume.attached?
  end


  has_many :applications, serializer: ApplicationSerializer
end
