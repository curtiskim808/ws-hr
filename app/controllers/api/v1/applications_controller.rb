module Api
  module V1
    # ApplicationsController - Manages job application CRUD and workflow operations
    #
    # T106, T107: Controller for managing job applications with action types
    # T143-T148: Enhanced filtering, pagination, and sorting
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
      include Pagy::Backend

      # Skip authentication for public application submission
      # This allows candidates to apply for jobs without an account
      skip_before_action :authenticate_api_user!, only: [ :create ]

      # CALLBACKS
      before_action :set_application, only: [ :show, :update, :destroy ]
      before_action :authorize_manage_applications!, only: [ :update, :destroy ]

      # INDEX - List all applications with filtering, pagination, and sorting
      # GET /api/v1/applications
      #
      # T143-T148: Enhanced filtering, pagination, and sorting
      # T153: Interviewer role filtering (only see applications with assigned interviews)
      #
      # QUERY PARAMETERS:
      # - status: Filter by status (in_progress, hired, rejected, archived)
      # - job_posting_id: Filter by job posting ID
      # - location_id: Filter by location (via job_posting)
      # - applicant_id: Filter by applicant ID
      # - page[number]: Page number (default: 1)
      # - page[size]: Items per page (default: 25, max: 100)
      # - sort: Sort field (created_at, applied_at, status, applicant_name)
      # - direction: Sort direction (asc, desc)
      #
      # RESPONSE: JSON:API formatted array with pagination meta
      # BRAND SCOPING: Automatic via BrandScoped concern
      # N+1 PREVENTION: Uses eager loading scopes (T148)
      # AUTHORIZATION: Interviewers only see applications with their assigned interviews (T153)
      def index
        # T148: Start with eager loading scopes to prevent N+1 queries
        applications = Application.with_applicant.with_job_posting

        # T153: Filter by interviewer role - only show applications with assigned interviews
        # NOTE: This will be fully implemented when Interview model is added (Phase 10, T179+)
        # For now, interviewers see all applications (same as other roles)
        # TODO: When interviews are implemented, add:
        #   if current_user&.role_interviewer?
        #     applications = applications.joins(:interviews).where(interviews: { interviewer_id: current_user.id })
        #   end
        if current_user&.role_interviewer?
          # Placeholder: When Interview model exists, filter by assigned interviews
          # For now, interviewers can see all applications (will be restricted in Phase 10)
          # applications = applications.joins(:interviews).where(interviews: { interviewer_id: current_user.id })
        end

        # Filter by status
        applications = applications.by_status(params[:status]) if params[:status].present?

        # Filter by job_posting_id
        applications = applications.where(job_posting_id: params[:job_posting_id]) if params[:job_posting_id].present?

        # Filter by location (via job_posting)
        applications = applications.for_location(params[:location_id]) if params[:location_id].present?

        # Filter by applicant_id
        applications = applications.where(applicant_id: params[:applicant_id]) if params[:applicant_id].present?

        # T147: Apply sorting
        applications = apply_sorting(applications)

        # T146: Apply pagination
        pagy, paginated_applications = pagy(applications, page: page_number, items: page_size)

        # Render with pagination meta
        render json: ApplicationSerializer.new(paginated_applications).serializable_hash.merge(
          meta: pagination_meta(pagy)
        )
      end

      # SHOW - Get a single application with full details
      # GET /api/v1/applications/:id
      #
      # RESPONSE: JSON object with application, applicant, job_posting, stage_transitions
      def show
        render json: ApplicationSerializer.new(
          @application,
          include: [ :applicant, :job_posting, :current_stage, :stage_transitions ]
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
        when "hire"
          @application.hire!(current_user)
        when "reject"
          @application.reject!(params[:rejection_reason], current_user)
        when "advance_stage"
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
          false
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

      # =============================================================================
      # T146-T147: PAGINATION & SORTING HELPERS
      # =============================================================================

      # T146: Get page number from params (JSON:API format)
      # Defaults to 1 if not specified
      def page_number
        params.dig(:page, :number)&.to_i || 1
      end

      # T146: Get page size from params (JSON:API format)
      # Defaults to 25, max 100
      def page_size
        size = params.dig(:page, :size)&.to_i || 25
        [ size, 100 ].min  # Cap at 100 items per page
      end

      # T147: Apply sorting to applications query
      # Supports: created_at, -created_at, status, applicant_name
      # Default: -created_at (newest first)
      # def apply_sorting(applications)
      #   sort_param = params[:sort] || '-created_at'

      #   case sort_param
      #   when 'created_at', '+created_at'
      #     applications.order(created_at: :asc)
      #   when '-created_at'
      #     applications.order(created_at: :desc)
      #   when 'status'
      #     applications.order(status: :asc, created_at: :desc)
      #     binding.pry
      #   when '-status'
      #     applications.order(status: :desc, created_at: :desc)
      #   when 'applicant_name'
      #     # Sort by applicant's full name (requires join)
      #     applications.joins(:applicant)
      #                 .order('applicants.last_name ASC', 'applicants.first_name ASC', 'applications.created_at DESC')
      #   when '-applicant_name'
      #     # Sort by applicant's full name descending
      #     applications.joins(:applicant)
      #                 .order('applicants.last_name DESC', 'applicants.first_name DESC', 'applications.created_at DESC')
      #   else
      #     # Default: newest first
      #     applications.order(created_at: :desc)
      #   end
      # end

      ALLOWED_SORT_FIELDS = %w[created_at applied_at status applicant_name].freeze
      DEFAULT_SORT_FIELD = "created_at".freeze
      DEFAULT_SORT_DIRECTION = "desc".freeze

      # Apply sorting from query parameters
      # PARAMS:
      # - sort: Field to sort by
      # - direction: asc or desc
      # default to desc for created_at/applied_at, asc for status/applicant_name in natural order
      def apply_sorting(scope)
        sort_field = params[:sort].presence || DEFAULT_SORT_FIELD
        sort_direction = params[:direction].presence

        # Validate sort field
        sort_field = DEFAULT_SORT_FIELD unless ALLOWED_SORT_FIELDS.include?(sort_field)

        # Default direction: asc for status/applicant_name, desc for created_at/applied_at
        unless sort_direction.present?
          sort_direction = if %w[status applicant_name].include?(sort_field)
                             "asc"
          else
                             DEFAULT_SORT_DIRECTION
          end
        end

        # Validate direction
        sort_direction = DEFAULT_SORT_DIRECTION unless %w[asc desc].include?(sort_direction.downcase)
        # Special handling for applicant_name (requires join)
        if sort_field == "applicant_name"
          scope.joins(:applicant).order("applicants.first_name #{sort_direction}, applicants.last_name #{sort_direction}")
        elsif sort_field == "status"
          # Status is an enum (integer: in_progress=0, hired=1, rejected=2, archived=3)
          # Use CASE to map integer values to string names for alphabetical sorting
          case_sql = <<-SQL.squish
            CASE applications.status
              WHEN 0 THEN 'in_progress'
              WHEN 1 THEN 'hired'
              WHEN 2 THEN 'rejected'
              WHEN 3 THEN 'archived'
            END #{sort_direction}
          SQL
          scope.order(Arel.sql(case_sql))
        else
          scope.order("applications.#{sort_field} #{sort_direction}")
        end
      end


      # T146: Build pagination meta for JSON:API response
      # Returns hash with pagination information
      def pagination_meta(pagy)
        {
          pagination: {
            current_page: pagy.page,
            per_page: pagy.items,
            total_pages: pagy.pages,
            total_count: pagy.count
          }
        }
      end
    end
  end
end
