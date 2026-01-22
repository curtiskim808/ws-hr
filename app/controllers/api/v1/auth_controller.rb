module Api
  module V1
    # AuthController - Handles authentication endpoints (login, logout)
    # EXPLANATION: This controller manages JWT-based authentication
    class AuthController < BaseController
      # IMPORTANT: Skip authentication for login endpoint
      skip_before_action :authenticate_api_user!, only: [ :login ]

      def login
        # In multi-tenant setup, you might want to require brand_id
        user = User.find_by(email: login_params[:email])

        if user&.valid_password?(login_params[:password])
          # STEP 3: Sign in user (sets up JWT token in response header)
          # sign_in is a Devise helper that triggers devise-jwt
          sign_in(user)

          render json: {
            message: "Logged in successfully",
            user: {
              id: user.id,
              email: user.email,
              first_name: user.first_name,
              last_name: user.last_name,
              role: user.role,
              brand_id: user.brand_id
            }
          }, status: :ok
        else
          # STEP 5: Return error if authentication fails
          render json: {
            error: "Invalid email or password"
          }, status: :unauthorized
        end
      end

      def logout
        # sign_out is a Devise helper that triggers devise-jwt
        sign_out(current_user)

        render json: {
          message: "Logged out successfully"
        }, status: :ok
      end

      private

      def login_params
        params.require(:auth).permit(:email, :password)
      rescue ActionController::ParameterMissing
        params.permit(:email, :password)
      end
    end
  end
end
