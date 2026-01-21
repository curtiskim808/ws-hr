module Api
  module V1
    # PositionTemplatesController - Manages position template CRUD operations
    #
    # THIN CONTROLLER PATTERN (DHH/37signals style):
    # - Each action is 1-5 lines max
    # - Business logic lives in the model
    # - Controller only coordinates between model and view (serializer)
    #
    # AUTHENTICATION & AUTHORIZATION:
    # - Inherits authentication from BaseController
    # - Only admins and hiring managers can manage templates
    # - Automatic brand scoping via BrandScoped concern in model
    class PositionTemplatesController < BaseController
      # CALLBACKS
      # T040: Set the template and authorize access before actions
      # NOTE: index and show allow any authenticated user
      # Only create, update, destroy require admin or hiring_manager role
      before_action :authorize_manage_templates!, only: [:create, :update, :destroy]
      before_action :set_position_template, only: [:show, :update, :destroy]
      

      # INDEX - List all position templates
      # GET /api/v1/position_templates
      #
      # QUERY PARAMETERS (optional):
      # - status: filter by status (draft, active)
      # - category: filter by category
      #
      # RESPONSE: JSON array of templates
      # BRAND SCOPING: Automatic via BrandScoped concern
      def index
        templates = PositionTemplate.all
        templates = templates.where(status: params[:status]) if params[:status].present?
        templates = templates.by_category(params[:category]) if params[:category].present?

        render json: PositionTemplateSerializer.new(templates).serializable_hash
      end

      # SHOW - Get a single position template
      # GET /api/v1/position_templates/:id
      #
      # RESPONSE: JSON object with template details
      def show
        render json: PositionTemplateSerializer.new(@position_template).serializable_hash
      end

      # CREATE - Create a new position template
      # POST /api/v1/position_templates
      #
      # REQUEST BODY: { position_template: { name, job_title, category, ... } }
      # RESPONSE: 201 Created with template JSON
      # ERROR: 422 Unprocessable Entity with validation errors
      def create
        template = PositionTemplate.create!(position_template_params)
        render json: PositionTemplateSerializer.new(template).serializable_hash, status: :created
      end

      # UPDATE - Update an existing position template
      # PATCH/PUT /api/v1/position_templates/:id
      #
      # REQUEST BODY: { position_template: { name, status, ... } }
      # RESPONSE: 200 OK with updated template JSON
      # ERROR: 422 Unprocessable Entity with validation errors
      def update
        @position_template.update!(position_template_params)
        render json: PositionTemplateSerializer.new(@position_template).serializable_hash
      end

      # DESTROY - Delete a position template
      # DELETE /api/v1/position_templates/:id
      #
      # RESPONSE: 204 No Content
      # ERROR: 422 if template has associated job_postings (prevent orphans)
      #
      # T044: The model's `dependent: :restrict_with_error` automatically
      # prevents deletion if job_postings exist
      def destroy
        @position_template.destroy!
        head :no_content
      end

      private

      # CALLBACK: Set the position template from params[:id]
      # BRAND SCOPING: Automatic via BrandScoped concern
      # SECURITY: User can only access templates from their brand
      def set_position_template
        @position_template = PositionTemplate.find(params[:id])
      end

      # AUTHORIZATION: Only admins and hiring managers can manage templates
      # SECURITY: Interviewers cannot create/edit templates
      # NOTE: This runs after authenticate_api_user!, so current_user should always exist
      # If current_user is nil here, it means authentication failed (shouldn't happen)
      def authorize_manage_templates!
        # If no user is authenticated, return 401 (authentication failed)
        # This should not normally happen since authenticate_api_user! should halt first
        unless current_user
          render json: { error: "Unauthorized" }, status: :unauthorized
          return false
        end

        # If user is authenticated but doesn't have required role, return 403 (forbidden)
        unless current_user.role_admin? || current_user.role_hiring_manager?
          render json: { error: "Unauthorized" }, status: :forbidden
          return false
        end
      end

      # STRONG PARAMETERS
      # T041: Whitelist allowed parameters for create/update
      # SECURITY: Prevents mass assignment vulnerabilities
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
    end
  end
end
