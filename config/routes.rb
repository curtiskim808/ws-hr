Rails.application.routes.draw do
  # DEVISE ROUTES
  # EXPLANATION: Skip default Devise routes since we're building a custom API
  # WHY: Devise's default routes are for HTML views, not JSON API
  # RESULT: We'll define custom auth routes below
  # NOTE: Keeping this line for now, but we use custom controllers
  devise_for :users, skip: :all

  # HEALTH CHECK ENDPOINT
  # EXPLANATION: Kubernetes/load balancer health check endpoint
  # USAGE: GET /up returns 200 if app is healthy, 500 if not
  # WHY: Essential for production deployments with load balancers
  get "up" => "rails/health#show", as: :rails_health_check

  # API ROUTES
  # EXPLANATION: All API endpoints are namespaced under /api/v1
  # WHY VERSIONING:
  # - Future-proof: Can add /api/v2 without breaking existing clients
  # - Best practice: API versioning is essential for public APIs
  # - Clean URLs: All API routes have consistent /api/v1 prefix
  #
  # ROUTING STRUCTURE:
  # /api/v1/auth/login   - POST   - Authentication (login)
  # /api/v1/auth/logout  - DELETE - Authentication (logout)
  # /api/v1/...          - Future resource routes will go here
  namespace :api do
    namespace :v1 do
      # AUTHENTICATION ROUTES
      # EXPLANATION: Custom authentication endpoints using our AuthController
      # WHY CUSTOM:
      # - API-only: Returns JSON, not HTML
      # - JWT tokens: Uses devise-jwt for token-based auth
      # - Flexibility: Full control over request/response format
      #
      # ENDPOINTS:
      # POST   /api/v1/auth/login  - Create session (login)
      #   Request:  { email: "user@example.com", password: "password123" }
      #   Response: { message: "Logged in successfully", user: { ... } }
      #   Header:   Authorization: Bearer <jwt_token>
      #
      # DELETE /api/v1/auth/logout - Destroy session (logout)
      #   Request:  Header: Authorization: Bearer <jwt_token>
      #   Response: { message: "Logged out successfully" }
      #
      # WHY THESE ROUTES:
      # - RESTful: login=POST (create), logout=DELETE (destroy)
      # - Standard: Follows Rails conventions for resourceful routing
      # - Clear: Explicit endpoint names (not /sessions/new)
      scope :auth do
        post 'login', to: 'auth#login'
        delete 'logout', to: 'auth#logout'
      end

      # RESOURCE ROUTES
      # T043: Position Templates (US1)
      # ENDPOINTS:
      # GET    /api/v1/position_templates      - List all templates
      # GET    /api/v1/position_templates/:id  - Get single template
      # POST   /api/v1/position_templates      - Create template
      # PATCH  /api/v1/position_templates/:id  - Update template
      # DELETE /api/v1/position_templates/:id  - Delete template
      #
      # AUTHENTICATION: Required (via BaseController)
      # AUTHORIZATION: Admin or Hiring Manager only
      # BRAND SCOPING: Automatic (via BrandScoped concern)
      resources :position_templates

      # FUTURE RESOURCE ROUTES
      # - resources :job_postings          # US2: Job Postings
      # - resources :applications          # US3: Applications
      # - resources :applicants            # US3: Applicants
      # - resources :availability_slots    # US6: Availability
      # - resources :interviews            # US7: Interviews
    end
  end
end
