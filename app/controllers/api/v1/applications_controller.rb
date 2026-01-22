module Api
  module V1
    class ApplicationsController < BaseController
      include Pagy::Backend

      # Skip authentication for public application submission
      skip_before_action :authenticate_api_user!, only: [ :create ]

      before_action :set_application, only: [ :show, :update, :destroy ]
      before_action :authorize_manage_applications!, only: [ :update, :destroy ]

      def index
        applications = Application.with_applicant.with_job_posting

        if current_user&.role_interviewer?
        end

        applications = applications.by_status(params[:status]) if params[:status].present?

        applications = applications.where(job_posting_id: params[:job_posting_id]) if params[:job_posting_id].present?

        applications = applications.for_location(params[:location_id]) if params[:location_id].present?

        applications = applications.where(applicant_id: params[:applicant_id]) if params[:applicant_id].present?

        applications = apply_sorting(applications)

        pagy, paginated_applications = pagy(applications, page: page_number, items: page_size)

        # Render with pagination meta
        render json: ApplicationSerializer.new(paginated_applications).serializable_hash.merge(
          meta: pagination_meta(pagy)
        )
      end

      def show
        render json: ApplicationSerializer.new(
          @application,
          include: [ :applicant, :job_posting, :current_stage, :stage_transitions ]
        ).serializable_hash
      end

      def create
        # Set brand from job_posting for public submissions
        job_posting = JobPosting.unscoped.find(params[:job_posting_id])
        Current.brand = job_posting.brand

        application = Application.create_from_form!(create_params)
        render json: ApplicationSerializer.new(application).serializable_hash, status: :created
      end

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
          @application.update!(application_params)
        end

        render json: ApplicationSerializer.new(@application.reload).serializable_hash
      end

      def destroy
        @application.archive!
        head :no_content
      end

      private

      # BRAND SCOPING: Automatic via BrandScoped concern
      def set_application
        @application = Application.find(params[:id])
      end

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

      def application_params
        params.require(:application).permit(:notes)
      end


      def page_number
        params.dig(:page, :number)&.to_i || 1
      end

      def page_size
        size = params.dig(:page, :size)&.to_i || 25
        [ size, 100 ].min  # Cap at 100 items per page
      end



      ALLOWED_SORT_FIELDS = %w[created_at applied_at status applicant_name].freeze
      DEFAULT_SORT_FIELD = "created_at".freeze
      DEFAULT_SORT_DIRECTION = "desc".freeze

      def apply_sorting(scope)
        sort_field = params[:sort].presence || DEFAULT_SORT_FIELD
        sort_direction = params[:direction].presence

        sort_field = DEFAULT_SORT_FIELD unless ALLOWED_SORT_FIELDS.include?(sort_field)

        unless sort_direction.present?
          sort_direction = if %w[status applicant_name].include?(sort_field)
                             "asc"
          else
                             DEFAULT_SORT_DIRECTION
          end
        end

        sort_direction = DEFAULT_SORT_DIRECTION unless %w[asc desc].include?(sort_direction.downcase)
        if sort_field == "applicant_name"
          scope.joins(:applicant).order("applicants.first_name #{sort_direction}, applicants.last_name #{sort_direction}")
        elsif sort_field == "status"
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
