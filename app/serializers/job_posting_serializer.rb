# JobPostingSerializer - T071
#
# PURPOSE: JSON:API formatted serialization for job postings
# WHY: Standardized response format with included relationships
# SPEC: https://jsonapi.org/
#
# RESPONSE FORMAT:
# {
#   "data": {
#     "id": "1",
#     "type": "job_posting",
#     "attributes": {
#       "job_title": "Backend Engineer - Payments Team",
#       "description": "Build scalable payment systems...",
#       "requirements": "5+ years Ruby on Rails...",
#       "status": "published",
#       "status_label": "Published",
#       "published_at": "2026-01-20T10:30:00Z",
#       "days_since_published": 1,
#       "accepting_applications": true,
#       "created_at": "2026-01-19T14:00:00Z",
#       "updated_at": "2026-01-20T10:30:00Z"
#     },
#     "relationships": {
#       "position_template": {
#         "data": { "id": "1", "type": "position_template" }
#       },
#       "location": {
#         "data": { "id": "2", "type": "location" }
#       }
#     }
#   },
#   "included": [
#     {
#       "id": "1",
#       "type": "position_template",
#       "attributes": { "name": "Software Engineer Template", ... }
#     },
#     {
#       "id": "2",
#       "type": "location",
#       "attributes": { "name": "San Francisco HQ", ... }
#     }
#   ]
# }
#
# WHY JSON:API:
#   - Standardized response format
#   - Automatic relationship handling
#   - Consistent pagination, filtering, sorting
#   - Client libraries available in all languages
class JobPostingSerializer
  include JSONAPI::Serializer

  # =============================================================================
  # ATTRIBUTES
  # =============================================================================
  # All fields exposed to the API

  # CORE FIELDS
  # job_title: Position title displayed on careers page
  # description: Full job description with responsibilities
  # requirements: Skills, experience, education needed
  attributes :job_title,
             :description,
             :requirements

  # STATUS FIELDS
  # status: Current state (draft, published, link_only, unpublished)
  # published_at: When posting was published
  # unpublished_at: When posting was unpublished
  # closed_at: When posting was manually closed
  attributes :status,
             :published_at,
             :unpublished_at,
             :closed_at

  # TIMESTAMPS
  # created_at: When posting was created
  # updated_at: When posting was last modified
  attributes :created_at,
             :updated_at

  # =============================================================================
  # COMPUTED ATTRIBUTES
  # =============================================================================
  # Custom attributes calculated from model methods

  # COMPUTED: status_label
  # PURPOSE: Human-readable status
  # EXAMPLE: "draft" → "Draft", "published" → "Published"
  attribute :status_label do |posting|
    posting.status.humanize
  end

  # COMPUTED: days_since_published
  # PURPOSE: How many days ago posting was published
  # RETURNS: Integer or null
  # USE CASE: Display "Posted 5 days ago" on careers page
  attribute :days_since_published do |posting|
    posting.days_since_published
  end

  # COMPUTED: accepting_applications
  # PURPOSE: Is posting currently accepting applications?
  # RETURNS: Boolean
  # BUSINESS RULE: Published or link_only postings accept applications
  attribute :accepting_applications do |posting|
    posting.accepting_applications?
  end

  # COMPUTED: visible_on_careers_page
  # PURPOSE: Does posting appear on public careers page?
  # RETURNS: Boolean
  # BUSINESS RULE: Only published postings are visible
  attribute :visible_on_careers_page do |posting|
    posting.visible_on_careers_page?
  end

  # =============================================================================
  # RELATIONSHIPS
  # =============================================================================
  # Related resources that can be included in response

  # RELATIONSHIP: position_template
  # PURPOSE: The template this posting was created from
  # INCLUDE: Pass ?include=position_template to include full data
  # USE CASE: Show template details alongside posting
  #
  # EXAMPLE QUERY:
  #   GET /api/v1/job_postings/1?include=position_template
  #   → Returns posting with full template data in "included" section
  belongs_to :position_template

  # RELATIONSHIP: location
  # PURPOSE: Where this job is located (SF HQ, Remote, NY Office)
  # INCLUDE: Pass ?include=location to include full data
  # USE CASE: Display location name, address on careers page
  #
  # EXAMPLE QUERY:
  #   GET /api/v1/job_postings/1?include=location
  #   → Returns posting with full location data in "included" section
  belongs_to :location

  # RELATIONSHIP: hiring_process
  # PURPOSE: The workflow applicants will follow
  # INCLUDE: Pass ?include=hiring_process to include full data
  # USE CASE: Show hiring stages to applicants
  #
  # EXAMPLE QUERY:
  #   GET /api/v1/job_postings/1?include=hiring_process
  #   → Returns posting with full hiring process data
  belongs_to :hiring_process

  # RELATIONSHIP: applications (collection)
  # PURPOSE: All applications submitted to this posting
  # NOTE: Typically not included in public API (internal only)
  # SECURITY: Only visible to authenticated admins/hiring managers
  # has_many :applications
  # NOTE: Commented out for now, will be added when applications are implemented
end
