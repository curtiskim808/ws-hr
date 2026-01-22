module Api
  module V1
    class ApplicantsController < BaseController
      include Pagy::Backend
      before_action :set_applicant, only: [ :show, :update ]
      before_action :authorize_manage_applicants!, only: [ :create, :update ]

      def index
        applicants = Applicant.recent

        applicants = applicants.by_source(params[:source]) if params[:source].present?

        applicants = applicants.flagged if params[:flagged] == "true"

        applicants = applicants_for_viewer(applicants)

        pagy, paginated_applicants = pagy(applicants, page: page_number, items: page_size)

        render json: ApplicantSerializer.new(paginated_applicants).serializable_hash.merge(
          meta: pagination_meta(pagy)
        )
      end

      def show
        render json: ApplicantSerializer.new(
          @applicant,
          include: [ :applications ]
        ).serializable_hash
      end

      def create
        applicant = Applicant.create!(applicant_params)
        render json: ApplicantSerializer.new(applicant).serializable_hash, status: :created
      end

      def update
        @applicant.update!(applicant_params)
        render json: ApplicantSerializer.new(@applicant).serializable_hash
      end

      private

      # BRAND SCOPING: Automatic via BrandScoped concern
      def set_applicant
        @applicant = applicants_for_viewer(Applicant.all).find(params[:id])
      end

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

      def applicants_for_viewer(scope)
        return scope unless current_user&.role_interviewer?

        if Object.const_defined?(:Interview) && Application.reflect_on_association(:interviews)
          scope.joins(applications: :interviews)
               .where(interviews: { interviewer_id: current_user.id })
               .distinct
        else
          scope.none
        end
      end

      # Pagination helpers (JSON:API format)
      def page_number
        params.dig(:page, :number)&.to_i || 1
      end

      def page_size
        size = params.dig(:page, :size)&.to_i || 25
        [ size, 100 ].min
      end

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
