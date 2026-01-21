module Api
  module V1
    # JobPostingsController - T067-T070
    #
    # PURPOSE: Manage job posting CRUD operations and status transitions
    # WHY: Job postings are created from templates and published to careers page
    # THIN CONTROLLER PATTERN (DHH/37signals style):
    #   - Each action is 1-5 lines max
    #   - Business logic lives in the model (AASM state machine)
    #   - Controller only coordinates between model and view (serializer)
    #
    # AUTHENTICATION & AUTHORIZATION:
    #   - Inherits authentication from BaseController
    #   - Only admins and hiring managers can manage postings
    #   - Automatic brand scoping via BrandScoped concern in model
    #
    # STATUS TRANSITIONS (T070):
    #   - publish! → draft to published
    #   - unpublish! → published to unpublished
    #   - make_link_only! → published to link_only
    #   - Handled via params[:status] in update action
    class JobPostingsController < BaseController
      # T068: CALLBACKS
      # Set the job posting and authorize access before actions
      before_action :set_job_posting, only: [:show, :update, :destroy]
      before_action :authorize_manage_postings!

      # INDEX - List all job postings
      # GET /api/v1/job_postings
      #
      # QUERY PARAMETERS (optional):
      #   - status: filter by status (draft, published, link_only, unpublished)
      #   - location_id: filter by location
      #
      # RESPONSE: JSON array of job postings
      # BRAND SCOPING: Automatic via BrandScoped concern
      #
      # EXAMPLE:
      #   GET /api/v1/job_postings?status=published&location_id=1
      def index
        postings = JobPosting.all
        postings = postings.where(status: params[:status]) if params[:status].present?
        postings = postings.at_location(params[:location_id]) if params[:location_id].present?
        postings = postings.recent # Order by most recent

        render json: JobPostingSerializer.new(postings).serializable_hash
      end

      # SHOW - Get a single job posting
      # GET /api/v1/job_postings/:id
      #
      # RESPONSE: JSON object with posting details
      # INCLUDES: position_template, location, hiring_process
      def show
        render json: JobPostingSerializer.new(@job_posting).serializable_hash
      end

      # CREATE - Create a new job posting
      # POST /api/v1/job_postings
      #
      # REQUEST BODY: { job_posting: { position_template_id, location_id, ... } }
      # RESPONSE: 201 Created with posting JSON
      # ERROR: 422 Unprocessable Entity with validation errors
      #
      # AUTO-POPULATION:
      #   - job_title, description, requirements copied from position_template
      #   - hiring_process set to brand's default
      #   - status defaults to 'draft'
      def create
        posting = JobPosting.create!(job_posting_params)
        render json: JobPostingSerializer.new(posting).serializable_hash, status: :created
      end

      # UPDATE - Update an existing job posting
      # PATCH/PUT /api/v1/job_postings/:id
      #
      # REQUEST BODY: { job_posting: { job_title, status, ... } }
      # RESPONSE: 200 OK with updated posting JSON
      # ERROR: 422 Unprocessable Entity with validation errors
      #
      # T070: STATUS TRANSITIONS
      #   If params[:status] is provided, trigger AASM event:
      #   - status: "published" → calls publish!
      #   - status: "unpublished" → calls unpublish!
      #   - status: "link_only" → calls make_link_only!
      def update
        # T070: Handle status transitions via AASM events
        # Return early if transition fails (handle_status_transition renders error response)
        return if params[:job_posting][:status].present? && handle_status_transition == false

        # Update other attributes
        @job_posting.update!(job_posting_params.except(:status))
        render json: JobPostingSerializer.new(@job_posting).serializable_hash
      end

      # DESTROY - Delete a job posting
      # DELETE /api/v1/job_postings/:id
      #
      # RESPONSE: 204 No Content
      # ERROR: 422 if posting has applications (prevent orphans)
      #
      # DELETION PREVENTION:
      #   Model's `dependent: :restrict_with_error` automatically
      #   prevents deletion if applications exist
      def destroy
        @job_posting.destroy!
        head :no_content
      end

      private

      # T068: CALLBACK: Set the job posting from params[:id]
      # BRAND SCOPING: Automatic via BrandScoped concern
      # SECURITY: User can only access postings from their brand
      def set_job_posting
        @job_posting = JobPosting.find(params[:id])
      end

      # T068: AUTHORIZATION: Only admins and hiring managers can manage postings
      # SECURITY: Interviewers cannot create/edit postings
      def authorize_manage_postings!
        unless current_user.role_admin? || current_user.role_hiring_manager?
          render json: { error: 'Unauthorized' }, status: :forbidden
        end
      end

      # T069: STRONG PARAMETERS
      # Whitelist allowed parameters for create/update
      # SECURITY: Prevents mass assignment vulnerabilities
      #
      # ALLOWED FIELDS:
      #   - position_template_id: FK to template
      #   - location_id: FK to location
      #   - hiring_process_id: FK to hiring process (optional, uses default)
      #   - job_title: Customizable title (copied from template by default)
      #   - description: Customizable description (copied from template by default)
      #   - requirements: Customizable requirements (copied from template by default)
      #   - status: For status transitions (handled separately in T070)
      def job_posting_params
        params.require(:job_posting).permit(
          :position_template_id,
          :location_id,
          :hiring_process_id,
          :job_title,
          :description,
          :requirements,
          :status
        )
      end

      # T070: PRIVATE METHOD: Handle status transitions
      # PURPOSE: Trigger AASM events based on status parameter
      # WHY: State machine handles transitions, callbacks, and validations
      #
      # TRANSITIONS:
      #   draft → published (publish!)
      #   published → unpublished (unpublish!)
      #   published → link_only (make_link_only!)
      #   link_only → published (publish!)
      #
      # EXAMPLE:
      #   PATCH /api/v1/job_postings/1
      #   { "job_posting": { "status": "published" } }
      #   → calls @job_posting.publish!
      def handle_status_transition
        target_status = params[:job_posting][:status]

        case target_status
        when 'published'
          @job_posting.publish! unless @job_posting.published?
        when 'unpublished'
          @job_posting.unpublish! unless @job_posting.unpublished?
        when 'link_only'
          @job_posting.make_link_only! unless @job_posting.link_only?
        end
        true # Return true to indicate success
      rescue AASM::InvalidTransition => e
        # If transition is invalid, AASM will raise error
        # Return 422 with error message
        render json: { error: e.message }, status: :unprocessable_entity
        false # Return false to indicate failure (prevents double render)
      end
    end
  end
end
