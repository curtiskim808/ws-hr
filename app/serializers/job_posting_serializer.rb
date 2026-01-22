# JobPostingSerializer
# JSON:API formatted serialization for job postings

class JobPostingSerializer
  include JSONAPI::Serializer


  attributes :job_title,
             :description,
             :requirements

  attributes :status,
             :published_at,
             :unpublished_at,
             :closed_at

  attributes :created_at,
             :updated_at


  attribute :status_label do |posting|
    posting.status.humanize
  end

  attribute :days_since_published do |posting|
    posting.days_since_published
  end

  attribute :accepting_applications do |posting|
    posting.accepting_applications?
  end

  # Does posting appear on public careers page?
  attribute :visible_on_careers_page do |posting|
    posting.visible_on_careers_page?
  end


  belongs_to :position_template

  belongs_to :location

  belongs_to :hiring_process

end
