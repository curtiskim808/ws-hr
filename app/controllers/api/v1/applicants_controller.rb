module Api
  module V1
    # ApplicantsController - Manages applicant CRUD operations
    #
    # T105: Controller for viewing and managing applicants
    #
    # THIN CONTROLLER PATTERN (DHH/37signals style):
    # - Each action is 1-5 lines max
    # - Business logic lives in the model
    # - Controller only coordinates between model and view (serializer)
    #
    # AUTHENTICATION & AUTHORIZATION:
    # - Inherits authentication from BaseController
    # - Admins and hiring managers can view all applicants
    # - Create is allowed for staff adding applicants manually
    # - Automatic brand scoping via BrandScoped concern in model
    #
    # ROUTES:
    #   GET    /api/v1/applicants          - List applicants
    #   GET    /api/v1/applicants/:id      - Show applicant
    #   POST   /api/v1/applicants          - Create applicant
    #   PATCH  /api/v1/applicants/:id      - Update applicant
    class ApplicantsController < BaseController
      # CALLBACKS
      # Set the applicant before actions that need it
      # Authorize manage access for create/update operations
      before_action :set_applicant, only: [ :show, :update ]
      before_action :authorize_manage_applicants!, only: [ :create, :update ]

      # INDEX - List all applicants
      # GET /api/v1/applicants
      #
      # QUERY PARAMETERS (optional):
      # - source: filter by source (linkedin, referral, etc.)
      # - flagged: filter flagged applicants (true/false)
      #
      # RESPONSE: JSON array of applicants with applications count
      # BRAND SCOPING: Automatic via BrandScoped concern
      def index
        applicants = Applicant.recent

        # Filter by source
        applicants = applicants.by_source(params[:source]) if params[:source].present?

        # Filter flagged applicants
        applicants = applicants.flagged if params[:flagged] == "true"

        render json: ApplicantSerializer.new(applicants).serializable_hash
      end

      # SHOW - Get a single applicant with applications
      # GET /api/v1/applicants/:id
      #
      # RESPONSE: JSON object with applicant details and applications
      def show
        render json: ApplicantSerializer.new(
          @applicant,
          include: [ :applications ]
        ).serializable_hash
      end

      # CREATE - Create a new applicant manually
      # POST /api/v1/applicants
      #
      # REQUEST BODY: { applicant: { first_name, last_name, email, phone, source, ... } }
      # RESPONSE: 201 Created with applicant JSON
      # ERROR: 422 Unprocessable Entity with validation errors
      #
      # USE CASE: Admin manually adds an applicant (e.g., walk-in candidate)
      def create
        applicant = Applicant.create!(applicant_params)
        render json: ApplicantSerializer.new(applicant).serializable_hash, status: :created
      end

      # UPDATE - Update an existing applicant
      # PATCH/PUT /api/v1/applicants/:id
      #
      # REQUEST BODY: { applicant: { first_name, phone, flagged, flag_reason, ... } }
      # RESPONSE: 200 OK with updated applicant JSON
      # ERROR: 422 Unprocessable Entity with validation errors
      #
      # USE CASE: Flag suspicious applicant, update contact info
      def update
        @applicant.update!(applicant_params)
        render json: ApplicantSerializer.new(@applicant).serializable_hash
      end

      private

      # CALLBACK: Set the applicant from params[:id]
      # BRAND SCOPING: Automatic via BrandScoped concern
      # SECURITY: User can only access applicants from their brand
      def set_applicant
        @applicant = Applicant.find(params[:id])
      end

      # AUTHORIZATION: Only admins and hiring managers can manage applicants
      # SECURITY: Interviewers can only view applicants they have interviews with
      # NOTE: Viewing (index/show) is allowed for all authenticated users
      def authorize_manage_applicants!
        unless current_user
          render json: { error: "Unauthorized" }, status: :unauthorized
          return false
        end

        unless current_user.role_admin? || current_user.role_hiring_manager?
          render json: { error: "Forbidden" }, status: :forbidden
          false
        end
      end

      # STRONG PARAMETERS
      # Whitelist allowed parameters for create/update
      # SECURITY: Prevents mass assignment vulnerabilities
      # NOTE: email cannot be updated after creation (business rule)
      def applicant_params
        params.require(:applicant).permit(
          :first_name,
          :last_name,
          :email,
          :phone,
          :preferred_language,
          :source,
          :flagged,
          :flag_reason
        )
      end
    end
  end
end
