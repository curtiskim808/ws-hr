# PositionTemplateSerializer - JSON:API formatted serialization

class PositionTemplateSerializer
  include JSONAPI::Serializer

  attributes :name,
             :job_title,
             :category,
             :department,
             :description,
             :requirements,
             :location_type,
             :employment_type,
             :education_requirement,
             :status,
             :created_at,
             :updated_at

  attribute :status_label do |template|
    template.status.humanize
  end
end
