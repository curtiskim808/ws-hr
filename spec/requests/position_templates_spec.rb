# Position Templates API Request Spec - Integration Testing
#
# TESTING PHILOSOPHY:
# - Test the full request/response cycle (integration testing)
# - Test authentication, authorization, and brand scoping
# - Test JSON:API response format
# - Test error handling and validation
#
# FIXTURE USAGE:
# - users(:acme_admin) - Authorized user (admin role)
# - users(:acme_hiring_manager) - Authorized user (hiring_manager role)
# - users(:acme_interviewer) - Unauthorized user (interviewer role)
# - users(:globex_admin) - Different brand (for multi-tenant testing)
# - position_templates(:software_engineer) - Active template
# - position_templates(:marketing_manager_draft) - Draft template
#
# T049: GET /api/v1/position_templates (index)
# T050: POST /api/v1/position_templates (create)

require 'rails_helper'

RSpec.describe 'Position Templates API', type: :request do
  # SETUP: Load fixtures for all tests
  fixtures :brands, :users, :position_templates

  # =============================================================================
  # AUTHENTICATION HELPER
  # =============================================================================
  # PURPOSE: Generate JWT token for authenticated requests
  # WHY: API requires 'Authorization: Bearer <token>' header
  # USAGE: headers = auth_headers(users(:acme_admin))

  def auth_headers(user)
    # Sign in the user to generate JWT token
    post '/api/v1/auth/login', params: {
      email: user.email,
      password: 'password123'  # All fixture users use this password
    }

    # Extract token from response headers
    token = response.headers['Authorization']&.split(' ')&.last

    # Return headers hash with Authorization header
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end

  # =============================================================================
  # T049: GET /api/v1/position_templates (INDEX)
  # =============================================================================
  # PURPOSE: Test listing position templates with filtering
  # SECURITY LAYERS:
  # 1. Authentication: Requires valid JWT token
  # 2. Authorization: Any authenticated user can list templates
  # 3. Brand Scoping: Only returns templates from user's brand

  describe 'GET /api/v1/position_templates' do
    # -------------------------------------------------------------------------
    # AUTHENTICATION TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Verify JWT authentication is enforced

    context 'without authentication' do
      it 'returns 401 unauthorized' do
        get '/api/v1/position_templates'

        expect(response).to have_http_status(:unauthorized)
      end
    end

    # -------------------------------------------------------------------------
    # BRAND SCOPING TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Verify multi-tenant data isolation
    # EXPECTATION: Users only see templates from their brand

    context 'with authenticated acme admin' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'returns only templates from acme brand' do
        get '/api/v1/position_templates', headers: headers

        expect(response).to have_http_status(:ok)

        # Parse JSON:API response
        json = JSON.parse(response.body)
        template_ids = json['data'].map { |t| t['id'].to_i }

        # Should include Acme templates
        expect(template_ids).to include(position_templates(:software_engineer).id)
        expect(template_ids).to include(position_templates(:sales_rep).id)
        expect(template_ids).to include(position_templates(:customer_support).id)

        # Should NOT include Globex templates
        expect(template_ids).not_to include(position_templates(:finance_analyst_globex).id)
      end

      it 'returns templates in JSON:API format' do
        get '/api/v1/position_templates', headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)

        # Verify JSON:API structure
        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)

        # Verify first template structure
        first_template = json['data'].first
        expect(first_template).to have_key('id')
        expect(first_template).to have_key('type')
        expect(first_template).to have_key('attributes')

        # Verify type
        expect(first_template['type']).to eq('position_template')

        # Verify attributes
        attributes = first_template['attributes']
        expect(attributes).to have_key('name')
        expect(attributes).to have_key('job_title')
        expect(attributes).to have_key('category')
        expect(attributes).to have_key('department')
        expect(attributes).to have_key('status')
        expect(attributes).to have_key('status_label')
      end
    end

    context 'with authenticated globex admin' do
      let(:headers) { auth_headers(users(:globex_admin)) }

      it 'returns only templates from globex brand' do
        get '/api/v1/position_templates', headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        template_ids = json['data'].map { |t| t['id'].to_i }

        # Should include Globex template
        expect(template_ids).to include(position_templates(:finance_analyst_globex).id)

        # Should NOT include Acme templates
        expect(template_ids).not_to include(position_templates(:software_engineer).id)
      end
    end

    # -------------------------------------------------------------------------
    # FILTERING TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Test query parameter filtering
    # ENDPOINTS: ?status=active, ?category=Engineering

    context 'with status filter' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'filters by active status' do
        get '/api/v1/position_templates', params: { status: 'active' }, headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        statuses = json['data'].map { |t| t['attributes']['status'] }

        # All returned templates should be active
        expect(statuses).to all(eq('active'))

        # Should NOT include draft templates
        template_ids = json['data'].map { |t| t['id'].to_i }
        expect(template_ids).not_to include(position_templates(:marketing_manager_draft).id)
      end

      it 'filters by draft status' do
        get '/api/v1/position_templates', params: { status: 'draft' }, headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        statuses = json['data'].map { |t| t['attributes']['status'] }

        # All returned templates should be draft
        expect(statuses).to all(eq('draft'))

        # Should include draft template
        template_ids = json['data'].map { |t| t['id'].to_i }
        expect(template_ids).to include(position_templates(:marketing_manager_draft).id)
      end
    end

    context 'with category filter' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'filters by Engineering category' do
        get '/api/v1/position_templates', params: { category: 'Engineering' }, headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        categories = json['data'].map { |t| t['attributes']['category'] }

        # All returned templates should be Engineering
        expect(categories).to all(eq('Engineering'))

        # Should include software_engineer
        template_ids = json['data'].map { |t| t['id'].to_i }
        expect(template_ids).to include(position_templates(:software_engineer).id)
        expect(template_ids).not_to include(position_templates(:sales_rep).id)
      end
    end

    context 'with combined filters' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'filters by status and category together' do
        get '/api/v1/position_templates', params: { status: 'active', category: 'Sales' }, headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)

        # Should return active Sales templates only
        expect(json['data'].length).to eq(1)
        expect(json['data'].first['attributes']['category']).to eq('Sales')
        expect(json['data'].first['attributes']['status']).to eq('active')
      end
    end

    # -------------------------------------------------------------------------
    # AUTHORIZATION TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Verify all authenticated users can list templates
    # NOTE: No role restriction on index action

    context 'with interviewer role (lowest permission)' do
      let(:headers) { auth_headers(users(:acme_interviewer)) }

      it 'allows listing templates' do
        get '/api/v1/position_templates', headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data'].length).to be > 0
      end
    end
  end

  # =============================================================================
  # SHOW: GET /api/v1/position_templates/:id
  # =============================================================================
  # PURPOSE: Test retrieving a single position template
  # SECURITY: Authentication + brand scoping

  describe 'GET /api/v1/position_templates/:id' do
    context 'without authentication' do
      it 'returns 401 unauthorized' do
        get "/api/v1/position_templates/#{position_templates(:software_engineer).id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with authenticated acme admin' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'returns the template in JSON:API format' do
        template = position_templates(:software_engineer)
        get "/api/v1/position_templates/#{template.id}", headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['data']['id'].to_i).to eq(template.id)
        expect(json['data']['type']).to eq('position_template')
        expect(json['data']['attributes']['name']).to eq(template.name)
        expect(json['data']['attributes']['job_title']).to eq(template.job_title)
      end

      it 'returns 404 for non-existent template' do
        get '/api/v1/position_templates/99999', headers: headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 for template from different brand' do
        # Try to access Globex template as Acme user
        globex_template = position_templates(:finance_analyst_globex)
        get "/api/v1/position_templates/#{globex_template.id}", headers: headers

        # Should return 404 due to brand scoping (template not found in Acme's scope)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # =============================================================================
  # T050: POST /api/v1/position_templates (CREATE)
  # =============================================================================
  # PURPOSE: Test creating position templates
  # SECURITY LAYERS:
  # 1. Authentication: Requires valid JWT token
  # 2. Authorization: Only admins and hiring_managers can create
  # 3. Brand Scoping: Automatic brand_id assignment from current_user
  # 4. Validation: Enforce required fields

  describe 'POST /api/v1/position_templates' do
    # -------------------------------------------------------------------------
    # AUTHENTICATION TESTS
    # -------------------------------------------------------------------------

    context 'without authentication' do
      it 'returns 401 unauthorized' do
        post '/api/v1/position_templates', params: {
          position_template: {
            name: 'New Template',
            job_title: 'New Position',
            category: 'Engineering',
            department: 'Product'
          }
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    # -------------------------------------------------------------------------
    # AUTHORIZATION TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Only admins and hiring_managers can create templates
    # INTERVIEWER ROLE: Should be denied (403 Forbidden)

    context 'with interviewer role (unauthorized)' do
      let(:headers) { auth_headers(users(:acme_interviewer)) }

      it 'returns 403 forbidden' do
        post '/api/v1/position_templates', params: {
          position_template: {
            name: 'New Template',
            job_title: 'New Position',
            category: 'Engineering',
            department: 'Product'
          }
        }, headers: headers

        expect(response).to have_http_status(:forbidden)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('Unauthorized')
      end
    end

    # -------------------------------------------------------------------------
    # SUCCESSFUL CREATION TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Test successful template creation with authorized users

    context 'with admin role (authorized)' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'creates a new position template' do
        expect {
          post '/api/v1/position_templates', params: {
            position_template: {
              name: 'Data Scientist Template',
              job_title: 'Senior Data Scientist',
              category: 'Data Science',
              department: 'Analytics',
              description: 'Build ML models and analyze data',
              requirements: 'PhD in CS or related field',
              location_type: 'hybrid',
              employment_type: 'full_time',
              education_requirement: 'doctorate',
              status: 'draft'
            }
          }, headers: headers
        }.to change(PositionTemplate, :count).by(1)

        expect(response).to have_http_status(:created)

        json = JSON.parse(response.body)
        expect(json['data']['attributes']['name']).to eq('Data Scientist Template')
        expect(json['data']['attributes']['job_title']).to eq('Senior Data Scientist')
        expect(json['data']['attributes']['status']).to eq('draft')
      end

      it 'automatically assigns brand_id from current_user' do
        post '/api/v1/position_templates', params: {
          position_template: {
            name: 'Auto Brand Template',
            job_title: 'Test Position',
            category: 'Engineering',
            department: 'Product'
          }
        }, headers: headers

        expect(response).to have_http_status(:created)

        # Verify template belongs to acme brand (user's brand)
        template = PositionTemplate.last
        expect(template.brand).to eq(brands(:acme))
      end
    end

    context 'with hiring_manager role (authorized)' do
      let(:headers) { auth_headers(users(:acme_hiring_manager)) }

      it 'creates a new position template' do
        expect {
          post '/api/v1/position_templates', params: {
            position_template: {
              name: 'HR Manager Template',
              job_title: 'HR Business Partner',
              category: 'Human Resources',
              department: 'People Ops'
            }
          }, headers: headers
        }.to change(PositionTemplate, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end

    # -------------------------------------------------------------------------
    # VALIDATION ERROR TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Test validation enforcement and error responses
    # EXPECTATION: 422 Unprocessable Entity with validation errors

    context 'with invalid parameters' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'returns 422 when name is missing' do
        post '/api/v1/position_templates', params: {
          position_template: {
            job_title: 'Test Position',
            category: 'Engineering',
            department: 'Product'
          }
        }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json['error']).to include("Name can't be blank")
      end

      it 'returns 422 when job_title is missing' do
        post '/api/v1/position_templates', params: {
          position_template: {
            name: 'Test Template',
            category: 'Engineering',
            department: 'Product'
          }
        }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json['error']).to include("Job title can't be blank")
      end

      it 'returns 422 when category is missing' do
        post '/api/v1/position_templates', params: {
          position_template: {
            name: 'Test Template',
            job_title: 'Test Position',
            department: 'Product'
          }
        }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json['error']).to include("Category can't be blank")
      end

      it 'returns 422 when department is missing' do
        post '/api/v1/position_templates', params: {
          position_template: {
            name: 'Test Template',
            job_title: 'Test Position',
            category: 'Engineering'
          }
        }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json['error']).to include("Department can't be blank")
      end

      it 'returns 422 when multiple fields are invalid' do
        post '/api/v1/position_templates', params: {
          position_template: {
            # Missing all required fields
          }
        }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        # Should include multiple validation errors
        expect(json['error']).to include("Name can't be blank")
        expect(json['error']).to include("Job title can't be blank")
        expect(json['error']).to include("Category can't be blank")
        expect(json['error']).to include("Department can't be blank")
      end
    end

    # -------------------------------------------------------------------------
    # STRONG PARAMETERS TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Verify only whitelisted parameters are accepted
    # SECURITY: Prevent mass assignment vulnerabilities

    context 'with unpermitted parameters' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'ignores unpermitted parameters' do
        post '/api/v1/position_templates', params: {
          position_template: {
            name: 'Test Template',
            job_title: 'Test Position',
            category: 'Engineering',
            department: 'Product',
            brand_id: brands(:globex).id,  # Attempt to set brand_id manually (should be ignored)
            malicious_field: 'hacked'       # Unpermitted parameter
          }
        }, headers: headers

        expect(response).to have_http_status(:created)

        template = PositionTemplate.last
        # brand_id should be set from current_user, not from params
        expect(template.brand).to eq(brands(:acme))
        # malicious_field should be ignored
        expect(template).not_to respond_to(:malicious_field)
      end
    end
  end

  # =============================================================================
  # UPDATE: PATCH /api/v1/position_templates/:id
  # =============================================================================
  # PURPOSE: Test updating position templates
  # SECURITY: Same as create (admin or hiring_manager only)

  describe 'PATCH /api/v1/position_templates/:id' do
    context 'with admin role' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'updates the position template' do
        template = position_templates(:marketing_manager_draft)

        patch "/api/v1/position_templates/#{template.id}", params: {
          position_template: {
            status: 'active',
            name: 'Updated Marketing Manager Template'
          }
        }, headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('active')
        expect(json['data']['attributes']['name']).to eq('Updated Marketing Manager Template')

        # Verify database was updated
        template.reload
        expect(template.status_active?).to be true
        expect(template.name).to eq('Updated Marketing Manager Template')
      end

      it 'returns 422 when update violates validations' do
        template = position_templates(:software_engineer)

        patch "/api/v1/position_templates/#{template.id}", params: {
          position_template: {
            name: ''  # Invalid: name can't be blank
          }
        }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with interviewer role (unauthorized)' do
      let(:headers) { auth_headers(users(:acme_interviewer)) }

      it 'returns 403 forbidden' do
        template = position_templates(:software_engineer)

        patch "/api/v1/position_templates/#{template.id}", params: {
          position_template: {
            name: 'Hacked Template'
          }
        }, headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # =============================================================================
  # DESTROY: DELETE /api/v1/position_templates/:id
  # =============================================================================
  # PURPOSE: Test deleting position templates
  # SECURITY: Same as create (admin or hiring_manager only)

  describe 'DELETE /api/v1/position_templates/:id' do
    context 'with admin role' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'deletes the position template' do
        template = position_templates(:minimal_template)

        expect {
          delete "/api/v1/position_templates/#{template.id}", headers: headers
        }.to change(PositionTemplate, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it 'returns 422 when template has associated job_postings' do
        template = position_templates(:software_engineer)

        # Create a job_posting for this template
        JobPosting.create!(
          brand: brands(:acme),
          position_template: template,
          title: 'Backend Engineer',
          status: :draft
        )

        expect {
          delete "/api/v1/position_templates/#{template.id}", headers: headers
        }.not_to change(PositionTemplate, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with interviewer role (unauthorized)' do
      let(:headers) { auth_headers(users(:acme_interviewer)) }

      it 'returns 403 forbidden' do
        template = position_templates(:minimal_template)

        delete "/api/v1/position_templates/#{template.id}", headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
