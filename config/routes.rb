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

      # T072: Job Postings (US2)
      # ENDPOINTS:
      # GET    /api/v1/job_postings      - List all job postings
      # GET    /api/v1/job_postings/:id  - Get single posting
      # POST   /api/v1/job_postings      - Create posting from template
      # PATCH  /api/v1/job_postings/:id  - Update posting or change status
      # DELETE /api/v1/job_postings/:id  - Delete posting
      #
      # AUTHENTICATION: Required (via BaseController)
      # AUTHORIZATION: Admin or Hiring Manager only
      # BRAND SCOPING: Automatic (via BrandScoped concern)
      #
      # STATUS TRANSITIONS (via PATCH):
      #   PATCH /api/v1/job_postings/:id { "job_posting": { "status": "published" } }
      #   → Triggers AASM events: publish!, unpublish!, make_link_only!
      #
      # QUERY PARAMETERS (index):
      #   ?status=published - Filter by status
      #   ?location_id=1 - Filter by location
      #   ?include=position_template,location - Include relationships
      resources :job_postings

      # T110: Applicants (US3)
      # ENDPOINTS:
      # GET    /api/v1/applicants      - List all applicants
      # GET    /api/v1/applicants/:id  - Get single applicant
      # POST   /api/v1/applicants      - Create applicant manually
      # PATCH  /api/v1/applicants/:id  - Update applicant (flag, contact info)
      #
      # AUTHENTICATION: Required (via BaseController)
      # AUTHORIZATION: Admin or Hiring Manager only for create/update
      # BRAND SCOPING: Automatic (via BrandScoped concern)
      #
      # QUERY PARAMETERS (index):
      #   ?source=linkedin - Filter by source
      #   ?flagged=true - Filter flagged applicants
      resources :applicants, only: [:index, :show, :create, :update]

      # T110: Applications (US3)
      # ENDPOINTS:
      # GET    /api/v1/applications      - List all applications
      # GET    /api/v1/applications/:id  - Get single application
      # POST   /api/v1/applications      - Submit application (PUBLIC - no auth)
      # PATCH  /api/v1/applications/:id  - Update/perform action (hire, reject, advance_stage)
      # DELETE /api/v1/applications/:id  - Archive application
      #
      # AUTHENTICATION: Required EXCEPT for POST (public submission)
      # AUTHORIZATION: Admin or Hiring Manager only for PATCH/DELETE
      # BRAND SCOPING: Automatic (via BrandScoped concern)
      #
      # ACTION TYPES (via PATCH):
      #   PATCH /api/v1/applications/:id { "action_type": "hire" }
      #   PATCH /api/v1/applications/:id { "action_type": "reject", "rejection_reason": "..." }
      #   PATCH /api/v1/applications/:id { "action_type": "advance_stage", "stage_id": 2 }
      #
      # QUERY PARAMETERS (index):
      #   ?status=in_progress - Filter by status
      #   ?job_posting_id=1 - Filter by job posting
      #   ?applicant_id=1 - Filter by applicant
      resources :applications

      # FUTURE RESOURCE ROUTES
      # - resources :availability_slots    # US6: Availability
      # - resources :interviews            # US7: Interviews
    end
  end
end
