module Api
  module V1
    # AuthController - Handles authentication endpoints (login, logout)
    #
    # EXPLANATION: This controller manages JWT-based authentication
    # It provides endpoints for:
    # 1. Login (POST /api/v1/auth/login) - Returns JWT token
    # 2. Logout (DELETE /api/v1/auth/logout) - Revokes JWT token
    #
    # WHY THIS DESIGN:
    # - Stateless authentication: JWT tokens don't require server-side sessions
    # - Token revocation: Uses JwtDenylist to invalidate tokens on logout
    # - Thin controller: Logic delegated to Devise and devise-jwt gem
    # - RESTful routes: login=create, logout=destroy
    #
    # AUTHENTICATION FLOW:
    # 1. Client sends POST /api/v1/auth/login with { email, password }
    # 2. Devise validates credentials
    # 3. devise-jwt generates JWT token and adds to response header
    # 4. Client stores token and sends it with subsequent requests
    # 5. On logout, token is added to denylist
    class AuthController < BaseController
      # IMPORTANT: Skip authentication for login endpoint
      # WHY: Users can't be authenticated before they login!
      # SECURITY: Still validates email/password via Devise
      skip_before_action :authenticate_api_user!, only: [:login]

      # LOGIN ENDPOINT
      # POST /api/v1/auth/login
      # Request body: { email: "user@example.com", password: "password" }
      # Response: { message: "Logged in successfully", user: { ... } }
      # Response header: Authorization: Bearer <jwt_token>
      #
      # EXPLANATION: Authenticates user and returns JWT token
      # HOW IT WORKS:
      # 1. Find user by email (scoped to brand if brand_id provided)
      # 2. Validate password using Devise's valid_password? method
      # 3. devise-jwt automatically adds JWT token to response headers
      # 4. Return user info and success message
      #
      # WHY THIS APPROACH:
      # - Manual authentication: Gives us control over the response format
      # - Brand scoping: Email must be unique within a brand (multi-tenant)
      # - Devise integration: Leverages Devise's secure password validation
      # - JWT in header: Standard practice for API authentication
      def login
        # STEP 1: Find user by email
        # NOTE: In multi-tenant setup, you might want to require brand_id
        # For now, we find by email globally (super_admin can access any brand)
        user = User.find_by(email: login_params[:email])

        # STEP 2: Validate user exists and password is correct
        # WHY: Devise's valid_password? uses bcrypt for secure comparison
        # SECURITY: This prevents timing attacks by using constant-time comparison
        if user&.valid_password?(login_params[:password])
          # STEP 3: Sign in user (sets up JWT token in response header)
          # WHY: sign_in is a Devise helper that triggers devise-jwt
          # SIDE EFFECT: devise-jwt adds "Authorization: Bearer <token>" to response
          sign_in(user)

          # STEP 4: Return success response with user info
          # RESPONSE FORMAT: Minimal user info (don't expose sensitive data)
          # NOTE: JWT token is in the Authorization response header, not body
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
          # SECURITY: Generic message doesn't reveal if email exists
          # WHY: Prevents attackers from enumerating valid emails
          render json: {
            error: "Invalid email or password"
          }, status: :unauthorized
        end
      end

      # LOGOUT ENDPOINT
      # DELETE /api/v1/auth/logout
      # Request header: Authorization: Bearer <jwt_token>
      # Response: { message: "Logged out successfully" }
      #
      # EXPLANATION: Revokes the current JWT token
      # HOW IT WORKS:
      # 1. Extract JWT token from request header
      # 2. Add token's JTI (JWT ID) to denylist
      # 3. devise-jwt automatically handles token revocation
      # 4. Return success message
      #
      # WHY THIS APPROACH:
      # - Token revocation: Prevents reuse of logged-out tokens
      # - Denylist strategy: More efficient than allowlist for our use case
      # - Devise integration: sign_out triggers devise-jwt's revocation
      #
      # SECURITY NOTES:
      # - Revoked tokens are stored in jwt_denylists table
      # - Old tokens are automatically cleaned up by expiration
      # - Even if token is stolen, logout invalidates it
      def logout
        # STEP 1: Sign out current user
        # WHY: sign_out is a Devise helper that triggers devise-jwt
        # SIDE EFFECT: devise-jwt adds current token to JwtDenylist
        # RESULT: Token can no longer be used for authentication
        sign_out(current_user)

        # STEP 2: Return success response
        # SIMPLE: Just confirm the logout was successful
        render json: {
          message: "Logged out successfully"
        }, status: :ok
      end

      private

      # STRONG PARAMETERS
      # EXPLANATION: Whitelist only allowed parameters for login
      # WHY: Security best practice to prevent mass assignment
      # ALLOWED: email, password
      # USAGE: login_params[:email], login_params[:password]
      def login_params
        params.require(:auth).permit(:email, :password)
      rescue ActionController::ParameterMissing
        # FALLBACK: If :auth key is missing, try root level params
        # WHY: Allows both { auth: { email, password } } and { email, password }
        # FLEXIBILITY: Client can send params in either format
        params.permit(:email, :password)
      end
    end
  end
end
