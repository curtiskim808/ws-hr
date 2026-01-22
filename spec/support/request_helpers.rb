# Request Helpers for RSpec
#
# PURPOSE: Provides authentication helpers for request specs
# WHY: API endpoints require JWT tokens in Authorization header
# USAGE: Include this module in request specs to get auth_headers helper
#
# Example:
#   let(:headers) { auth_headers(users(:acme_admin)) }
#   get '/api/v1/position_templates', headers: headers

module RequestHelpers
  # Generate authentication headers for a user
  #
  # @param user [User] The user to authenticate
  # @return [Hash] Headers hash with Authorization and Content-Type
  #
  # HOW IT WORKS:
  # 1. Makes a POST request to /api/v1/auth/login with user credentials
  # 2. Extracts JWT token from the Authorization response header
  # 3. Returns headers hash with Bearer token for subsequent requests
  #
  # NOTE: This method makes an actual HTTP request, so it should be called
  # in a let block or before block, not in the test itself
  def auth_headers(user)
    # Make login request to get JWT token
    # The login endpoint accepts params in format: { email, password } or { auth: { email, password } }
    # We use the root-level format: { email, password }
    # Use as: :json to send JSON body instead of form data
    post '/api/v1/auth/login',
      params: {
        email: user.email,
        password: 'password123'  # All fixture users use this password
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }

    # Check if login was successful
    unless response.status == 200
      raise "Login failed with status #{response.status}. Response: #{response.body}"
    end

    # Extract token from response headers
    # devise-jwt adds the token to the Authorization header after sign_in(user)
    # The header format is: "Authorization: Bearer <token>"
    auth_header = response.headers['Authorization'] ||
                  response.headers['authorization'] ||
                  response.get_header('Authorization')

    if auth_header.blank?
      # Try to get it from the response object directly
      auth_header = response.headers.to_h.find { |k, _| k.downcase == 'authorization' }&.last
    end

    if auth_header.blank?
      raise "Failed to get JWT token from login response. Status: #{response.status}, " \
            "Body: #{response.body}, Headers: #{response.headers.to_h.keys}"
    end

    # Extract token (format: "Bearer <token>" or just "<token>")
    token = auth_header.to_s.sub(/^Bearer /i, '').strip

    if token.blank?
      raise "JWT token is blank in Authorization header: #{auth_header.inspect}"
    end

    # Return headers hash for use in subsequent requests
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end

  # Generate headers with invalid token (for testing authentication failures)
  #
  # @return [Hash] Headers hash with invalid token
  def non_auth_headers
    {
      'Authorization' => 'Bearer invalid_token',
      'Content-Type' => 'application/json'
    }
  end
end

# Include the module in request specs
RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
