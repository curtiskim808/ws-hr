module Api
  module V1
    class PositionTemplatesController < BaseController
      include Pagy::Backend
      before_action :authorize_manage_templates!, only: [ :create, :update, :destroy ]
      before_action :set_position_template, only: [ :show, :update, :destroy ]


      def index
        templates = PositionTemplate.all

        templates = templates.where(status: params[:status]) if params[:status].present?

        templates = templates.by_category(params[:category]) if params[:category].present?

        pagy, paginated_templates = pagy(templates, page: page_number, items: page_size)

        render json: PositionTemplateSerializer.new(paginated_templates).serializable_hash.merge(
          meta: pagination_meta(pagy)
        )
      end

      def show
        render json: PositionTemplateSerializer.new(@position_template).serializable_hash
      end

      def create
        template = PositionTemplate.create!(position_template_params)
        render json: PositionTemplateSerializer.new(template).serializable_hash, status: :created
      end

      def update
        @position_template.update!(position_template_params)
        render json: PositionTemplateSerializer.new(@position_template).serializable_hash
      end

      def destroy
        @position_template.destroy!
        head :no_content
      end

      private

      # BRAND SCOPING: Automatic via BrandScoped concern
      def set_position_template
        @position_template = PositionTemplate.find(params[:id])
      end

      def authorize_manage_templates!
        # If no user is authenticated, return 401 (authentication failed)
        unless current_user
          render json: { error: "Unauthorized" }, status: :unauthorized
          return false
        end

        unless current_user.role_admin? || current_user.role_hiring_manager?
          render json: { error: "Unauthorized" }, status: :forbidden
          false
        end
      end

      def position_template_params
        params.require(:position_template).permit(
          :name,
          :job_title,
          :category,
          :department,
          :description,
          :requirements,
          :location_type,
          :employment_type,
          :education_requirement,
          :status
        )
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
