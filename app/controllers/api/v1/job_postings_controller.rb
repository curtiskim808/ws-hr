module Api
  module V1
    class JobPostingsController < BaseController
      include Pagy::Backend
      before_action :set_job_posting, only: [ :show, :update, :destroy ]
      before_action :authorize_manage_postings!

      def index
        postings = JobPosting.all

        postings = postings.where(status: params[:status]) if params[:status].present?

        postings = postings.at_location(params[:location_id]) if params[:location_id].present?

        postings = postings.recent # Order by most recent

        pagy, paginated_postings = pagy(postings, page: page_number, items: page_size)

        render json: JobPostingSerializer.new(paginated_postings).serializable_hash.merge(
          meta: pagination_meta(pagy)
        )
      end

      def show
        render json: JobPostingSerializer.new(@job_posting).serializable_hash
      end

      def create
        posting = JobPosting.create!(job_posting_params)
        render json: JobPostingSerializer.new(posting).serializable_hash, status: :created
      end

      def update
        # Return early if transition fails (handle_status_transition renders error response)
        return if params[:job_posting][:status].present? && handle_status_transition == false

        @job_posting.update!(job_posting_params.except(:status))
        render json: JobPostingSerializer.new(@job_posting).serializable_hash
      end

      def destroy
        @job_posting.destroy!
        head :no_content
      end

      private

      # BRAND SCOPING: Automatic via BrandScoped concern
      def set_job_posting
        @job_posting = JobPosting.find(params[:id])
      end

      def authorize_manage_postings!
        unless current_user.role_admin? || current_user.role_hiring_manager?
          render json: { error: "Unauthorized" }, status: :forbidden
        end
      end

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

      def handle_status_transition
        target_status = params[:job_posting][:status]

        case target_status
        when "published"
          @job_posting.publish! unless @job_posting.published?
        when "unpublished"
          @job_posting.unpublish! unless @job_posting.unpublished?
        when "link_only"
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
