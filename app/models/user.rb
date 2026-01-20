class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  # Associations
  belongs_to :brand
  has_many :location_assignments, dependent: :destroy
  has_many :locations, through: :location_assignments

  # Enums
  enum :role, {
    super_admin: 0,
    admin: 1,
    hiring_manager: 2,
    interviewer: 3
  }, prefix: true

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, uniqueness: { scope: :brand_id }
  validates :role, presence: true

  # Authorization methods
  def can_manage_application?(application)
    role_super_admin? || role_admin? ||
      (role_hiring_manager? && assigned_to_location?(application.job_posting.location_id))
  end

  def can_schedule_interview?(application)
    role_super_admin? || role_admin? ||
      (role_hiring_manager? && assigned_to_location?(application.job_posting.location_id))
  end

  def can_publish_job_posting?(job_posting)
    role_super_admin? || role_admin? ||
      (role_hiring_manager? && assigned_to_location?(job_posting.location_id))
  end

  private

  def assigned_to_location?(location_id)
    location_ids.include?(location_id)
  end
end
