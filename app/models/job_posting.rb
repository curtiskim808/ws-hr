class JobPosting < ApplicationRecord
  # MULTI-TENANT SCOPING
  # Include BrandScoped concern to automatically scope all queries to Current.brand
  # This ensures users only see job_postings from their own brand
  include BrandScoped

  # ASSOCIATIONS
  belongs_to :position_template
  # NOTE: belongs_to :location and belongs_to :hiring_process will be added in future tasks

  # VALIDATIONS
  # Basic validations - more will be added in future tasks
  validates :position_template_id, presence: true
end
