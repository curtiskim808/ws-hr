module Api
  module V1
    # ApplicationsController - Manages job application CRUD and workflow operations
    #
    # T106, T107: Controller for managing job applications with action types
    #
    # THIN CONTROLLER PATTERN (DHH/37signals style):
    # - Each action is 1-5 lines max
    # - Business logic lives in the model (hire!, reject!, advance_to_stage!)
    # - Controller only coordinates between model and view (serializer)
    #
    # AUTHENTICATION & AUTHORIZATION:
    # - Inherits authentication from BaseController
    # - Admins and hiring managers can manage all applications
    # - Interviewers can only view applications they have interviews for
    # - Public create endpoint for applicants (skip_before_action for create)
    #
    # ACTION TYPES (for update):
    # - hire: Hire the applicant (calls Application#hire!)
    # - reject: Reject the applicant (calls Application#reject!)
    # - advance_stage: Move to next stage (calls Application#advance_to_stage!)
    #
    # ROUTES:
    #   GET    /api/v1/applications          - List applications
    #   GET    /api/v1/applications/:id      - Show application
    #   POST   /api/v1/applications          - Create application (public)
    #   PATCH  /api/v1/applications/:id      - Update application (hire/reject/advance)
    #   DELETE /api/v1/applications/:id      - Archive application
    class ApplicationsController < BaseController
      # Skip authentication for public application submission
      # This allows candidates to apply for jobs without an account
      skip_before_action :authenticate_api_user!, only: [:create]

      # CALLBACKS
      before_action :set_application, only: [:show, :update, :destroy]
      before_action :authorize_manage_applications!, only: [:update, :destroy]

      # INDEX - List all applications
      # GET /api/v1/applications
      #
      # QUERY PARAMETERS (optional):
      # - status: filter by status (in_progress, hired, rejected, archived)
      # - job_posting_id: filter by job posting
      # - applicant_id: filter by applicant
      #
      # RESPONSE: JSON array of applications with applicant and job_posting
      # BRAND SCOPING: Automatic via BrandScoped concern
      def index
        applications = Application.recent
                                  .with_applicant
                                  .with_job_posting

        # Filter by status
        applications = applications.by_status(params[:status]) if params[:status].present?

        # Filter by job_posting_id
        applications = applications.where(job_posting_id: params[:job_posting_id]) if params[:job_posting_id].present?

        # Filter by applicant_id
        applications = applications.where(applicant_id: params[:applicant_id]) if params[:applicant_id].present?

        render json: ApplicationSerializer.new(applications).serializable_hash
      end

      # SHOW - Get a single application with full details
      # GET /api/v1/applications/:id
      #
      # RESPONSE: JSON object with application, applicant, job_posting, stage_transitions
      def show
        render json: ApplicationSerializer.new(
          @application,
          include: [:applicant, :job_posting, :current_stage, :stage_transitions]
        ).serializable_hash
      end

      # CREATE - Submit a new job application (PUBLIC ENDPOINT)
      # POST /api/v1/applications
      #
      # NOTE: Authentication is SKIPPED for this action
      # This is the public endpoint for candidates to apply for jobs
      #
      # REQUEST BODY:
      # {
      #   "job_posting_id": 1,
      #   "applicant": {
      #     "first_name": "John",
      #     "last_name": "Doe",
      #     "email": "john@example.com",
      #     "phone": "555-0100",
      #     "source": "linkedin"
      #   },
      #   "notes": "Interested in remote work"
      # }
      #
      # RESPONSE: 201 Created with application JSON
      # ERROR: 422 Unprocessable Entity with validation errors
      #
      # IMPLEMENTATION:
      # Uses Application.create_from_form! which:
      # 1. Finds or creates applicant by email
      # 2. Creates application linked to job_posting
      # 3. Sets hiring_process from job_posting
      # 4. Sets current_stage to first stage
      def create
        # Set brand from job_posting for public submissions
        job_posting = JobPosting.unscoped.find(params[:job_posting_id])
        Current.brand = job_posting.brand

        application = Application.create_from_form!(create_params)
        render json: ApplicationSerializer.new(application).serializable_hash, status: :created
      end

      # UPDATE - Update application or perform workflow action
      # PATCH/PUT /api/v1/applications/:id
      #
      # T107: Handle action types (hire, reject, advance_stage)
      #
      # REQUEST BODY (action types):
      # { "action": "hire" }
      # { "action": "reject", "rejection_reason": "Not enough experience" }
      # { "action": "advance_stage", "stage_id": 2, "notes": "Passed phone screen" }
      #
      # REQUEST BODY (regular update):
      # { "application": { "notes": "Follow up next week" } }
      #
      # RESPONSE: 200 OK with updated application JSON
      # ERROR: 422 Unprocessable Entity with validation errors
      def update
        case params[:action_type]
        when 'hire'
          @application.hire!(current_user)
        when 'reject'
          @application.reject!(params[:rejection_reason], current_user)
        when 'advance_stage'
          stage = HiringStage.find(params[:stage_id])
          @application.advance_to_stage!(stage, current_user, params[:notes])
        else
          # Regular update (notes, etc.)
          @application.update!(application_params)
        end

        render json: ApplicationSerializer.new(@application.reload).serializable_hash
      end

      # DESTROY - Archive an application
      # DELETE /api/v1/applications/:id
      #
      # RESPONSE: 204 No Content
      #
      # NOTE: This archives the application, not deletes it
      # Use AASM archive! event to maintain audit trail
      def destroy
        @application.archive!
        head :no_content
      end

      private

      # CALLBACK: Set the application from params[:id]
      # BRAND SCOPING: Automatic via BrandScoped concern
      # SECURITY: User can only access applications from their brand
      def set_application
        @application = Application.find(params[:id])
      end

      # AUTHORIZATION: Only admins and hiring managers can manage applications
      # SECURITY: Interviewers can only view (not modify) applications
      def authorize_manage_applications!
        unless current_user
          render json: { error: "Unauthorized" }, status: :unauthorized
          return false
        end

        unless current_user.role_admin? || current_user.role_hiring_manager?
          render json: { error: "Forbidden" }, status: :forbidden
          return false
        end
      end

      # STRONG PARAMETERS for public application submission
      # T107: Parameters for create_from_form!
      def create_params
        params.permit(
          :job_posting_id,
          :notes,
          applicant: [
            :first_name,
            :last_name,
            :email,
            :phone,
            :preferred_language,
            :source
          ]
        )
      end

      # STRONG PARAMETERS for regular updates
      # Only allows notes field for regular updates
      # Action types (hire, reject, advance_stage) use different params
      def application_params
        params.require(:application).permit(:notes)
      end
    end
  end
end
