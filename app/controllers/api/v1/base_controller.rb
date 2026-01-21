module Api
  module V1
    # BaseController - Foundation for all API v1 controllers
    #
    # EXPLANATION: This controller establishes the core patterns for the entire API:
    # 1. JWT Authentication - Uses Devise JWT for stateless authentication
    # 2. Multi-tenant Brand Scoping - Automatically scopes all queries to current brand
    # 3. Current Attributes - Sets Current.user and Current.brand for the request
    # 4. Error Handling - Provides consistent JSON error responses
    #
    # WHY THIS DESIGN:
    # - Thin controller pattern: All controllers inherit common behavior here
    # - DRY principle: Authentication and brand scoping defined once
    # - Current attributes pattern (DHH style): Accessible anywhere in request cycle
    # - Consistent error responses: All API errors follow same JSON structure
    class BaseController < ActionController::API
      # AUTHENTICATION
      # Uses Devise's authenticate_user! method provided by devise-jwt
      # This validates the JWT token from the Authorization header
      # Format: "Authorization: Bearer <token>"
      before_action :authenticate_user!

      # CURRENT ATTRIBUTES SETUP
      # These methods set thread-local variables accessible via Current.user and Current.brand
      # This is the DHH/37signals pattern for request-scoped context
      before_action :set_current_user
      before_action :set_current_brand

      # ERROR HANDLING
      # Catches common exceptions and returns standardized JSON error responses
      # This ensures the API always returns consistent error formats
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :bad_request

      private

      # EXPLANATION: Sets Current.user from Devise's current_user
      # WHY: Makes the authenticated user accessible anywhere via Current.user
      # USAGE: In models, services, etc. you can call Current.user
      def set_current_user
        Current.user = current_user
      end

      # EXPLANATION: Sets Current.brand from the authenticated user's brand
      # WHY: Enables automatic brand scoping in all queries via BrandScoped concern
      # SECURITY: This ensures users can only access data from their own brand
      # USAGE: Models with BrandScoped concern automatically filter by Current.brand
      def set_current_brand
        Current.brand = current_user&.brand
      end

      # ERROR RESPONSE METHODS
      # These methods provide consistent JSON error responses across the API

      # EXPLANATION: Returns 404 Not Found for missing records
      # USAGE: Automatically called when ActiveRecord::RecordNotFound is raised
      # RESPONSE FORMAT: { error: "Resource not found", message: "..." }
      def not_found(exception)
        render json: {
          error: "Resource not found",
          message: exception.message
        }, status: :not_found
      end

      # EXPLANATION: Returns 422 Unprocessable Entity for validation errors
      # USAGE: Automatically called when ActiveRecord::RecordInvalid is raised
      # RESPONSE FORMAT: { error: "Validation failed", errors: { field: ["message"] } }
      # WHY: Validation errors include field-specific messages for client-side display
      def unprocessable_entity(exception)
        render json: {
          error: "Validation failed",
          errors: exception.record.errors.messages
        }, status: :unprocessable_entity
      end

      # EXPLANATION: Returns 400 Bad Request for missing required parameters
      # USAGE: Automatically called when ActionController::ParameterMissing is raised
      # RESPONSE FORMAT: { error: "Bad request", message: "param is missing or empty: ..." }
      def bad_request(exception)
        render json: {
          error: "Bad request",
          message: exception.message
        }, status: :bad_request
      end

      # UTILITY METHODS

      # EXPLANATION: Helper to get current brand (delegates to Current.brand)
      # WHY: Provides convenient access pattern consistent with current_user
      # USAGE: In controller actions, you can call current_brand instead of Current.brand
      def current_brand
        Current.brand
      end
    end
  end
end
