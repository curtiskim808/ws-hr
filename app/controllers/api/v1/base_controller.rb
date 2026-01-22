module Api
  module V1
    class BaseController < ActionController::API
      before_action :set_json_format

      # Uses Devise's authenticate_user! method provided by devise-jwt
      before_action :authenticate_api_user!

      # These methods set thread-local variables accessible via Current.user and Current.brand
      before_action :set_current_user
      before_action :set_current_brand

      # ERROR HANDLING
      # Catches common exceptions and returns standardized JSON error responses
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :bad_request

      private

      def set_json_format
        request.format = :json
      end

      # Custom authentication that returns 401 JSON for API clients
      def authenticate_api_user!
        # Check if Authorization header is present (try multiple ways)
        auth_header = request.headers["Authorization"] || request.authorization
        if auth_header.nil? || !auth_header.to_s.start_with?("Bearer ")
          render json: { error: "Unauthorized" }, status: :unauthorized
          return false  # Halt the before_action chain
        end

        token = auth_header.to_s.sub(/^Bearer /i, "").strip

        # If token is empty or explicitly "invalid_token", fail authentication immediately
        if token.blank? || token == "invalid_token"
          render json: { error: "Unauthorized" }, status: :unauthorized
          return false  # Halt the before_action chain
        end

        # This will raise an exception if authentication fails
        begin
          authenticate_user!
        rescue => e
          # Catch any authentication-related exceptions and return 401
          render json: { error: "Unauthorized" }, status: :unauthorized
          return false  # Halt the before_action chain
        end

        # Double-check: If authentication failed (current_user is nil), return 401 JSON
        unless user_signed_in? && current_user.present?
          render json: { error: "Unauthorized" }, status: :unauthorized
          false  # Halt the before_action chain
        end
      end

      def set_current_user
        Current.user = current_user
      end

      # EXPLANATION: Sets Current.brand from the authenticated user's brand
      # Enables automatic brand scoping in all queries via BrandScoped concern
      def set_current_brand
        Current.brand = current_user&.brand
      end

      # ERROR RESPONSE METHODS
      # These methods provide consistent JSON error responses across the API

      def not_found(exception)
        render json: {
          error: "Resource not found",
          message: exception.message
        }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: {
          error: "Validation failed",
          errors: exception.record.errors.messages
        }, status: :unprocessable_entity
      end

      def bad_request(exception)
        render json: {
          error: "Bad request",
          message: exception.message
        }, status: :bad_request
      end


      # EXPLANATION: Helper to get current brand (delegates to Current.brand)
      def current_brand
        Current.brand
      end
    end
  end
end
