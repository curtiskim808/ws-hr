# Job Postings API Request Spec - T077, T078
#
# TESTING PHILOSOPHY:
# - Test the full request/response cycle (integration testing)
# - Test authentication, authorization, and brand scoping
# - Test JSON:API response format
# - Test error handling and validation
# - Test AASM state transitions via API
#
# FIXTURE USAGE:
# - users(:acme_admin) - Authorized user (admin role)
# - users(:acme_hiring_manager) - Authorized user (hiring_manager role)
# - users(:acme_interviewer) - Unauthorized user (interviewer role)
# - users(:globex_admin) - Different brand (for multi-tenant testing)
# - job_postings(:backend_engineer_published) - Published posting
# - job_postings(:marketing_manager_draft) - Draft posting
# - job_postings(:devops_engineer_link_only) - Link-only posting
#
# T077: GET /api/v1/job_postings (index) with filtering
# T078: PATCH /api/v1/job_postings/:id with status transitions

require 'rails_helper'

RSpec.describe 'Job Postings API', type: :request do
  # SETUP: Load fixtures for all tests
  fixtures :brands, :users, :locations, :position_templates, :hiring_processes, :hiring_stages, :job_postings

  # =============================================================================
  # T077: GET /api/v1/job_postings (INDEX)
  # =============================================================================
  # PURPOSE: Test listing job postings with filtering
  # SECURITY LAYERS:
  # 1. Authentication: Requires valid JWT token
  # 2. Authorization: Admin or Hiring Manager only
  # 3. Brand Scoping: Only returns postings from user's brand

  describe 'GET /api/v1/job_postings' do
    # -------------------------------------------------------------------------
    # AUTHENTICATION TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Verify JWT authentication is enforced

    context 'without authentication' do
      let(:headers) { non_auth_headers }

      it 'returns 401 unauthorized' do
        get '/api/v1/job_postings', headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    # -------------------------------------------------------------------------
    # AUTHORIZATION TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Verify only admins and hiring managers can list postings

    context 'with interviewer role (unauthorized)' do
      let(:headers) { auth_headers(users(:acme_interviewer)) }

      it 'returns 403 forbidden' do
        get '/api/v1/job_postings', headers: headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    # -------------------------------------------------------------------------
    # BRAND SCOPING TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Verify multi-tenant data isolation
    # EXPECTATION: Users only see postings from their brand

    context 'with authenticated admin' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'returns only postings from acme brand' do
        get '/api/v1/job_postings', headers: headers

        expect(response).to have_http_status(:ok)

        # Parse JSON:API response
        json = JSON.parse(response.body)
        posting_ids = json['data'].map { |p| p['id'].to_i }

        # Should include Acme postings
        expect(posting_ids).to include(job_postings(:backend_engineer_published).id)
        expect(posting_ids).to include(job_postings(:sales_rep_published).id)
        expect(posting_ids).to include(job_postings(:marketing_manager_draft).id)

        # Should NOT include Globex postings
        expect(posting_ids).not_to include(job_postings(:globex_engineer_published).id)
      end

      it 'returns postings in JSON:API format' do
        get '/api/v1/job_postings', headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)

        # Verify JSON:API structure
        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)

        # Verify first posting structure
        first_posting = json['data'].first
        expect(first_posting).to have_key('id')
        expect(first_posting).to have_key('type')
        expect(first_posting['type']).to eq('job_posting')
        expect(first_posting).to have_key('attributes')

        # Verify attributes
        attributes = first_posting['attributes']
        expect(attributes).to have_key('job_title')
        expect(attributes).to have_key('description')
        expect(attributes).to have_key('requirements')
        expect(attributes).to have_key('status')
        expect(attributes).to have_key('published_at')
      end
    end

    # -------------------------------------------------------------------------
    # FILTERING TESTS - BY STATUS
    # -------------------------------------------------------------------------
    # PURPOSE: Test filtering by status parameter
    # EXPECTATION: ?status=published returns only published postings

    context 'with status filter' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'filters by status=published' do
        get '/api/v1/job_postings', headers: headers, params: { status: 'published' }

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        statuses = json['data'].map { |p| p['attributes']['status'] }

        # All postings should be published
        expect(statuses).to all(eq('published'))

        # Verify specific postings
        posting_ids = json['data'].map { |p| p['id'].to_i }
        expect(posting_ids).to include(job_postings(:backend_engineer_published).id)
        expect(posting_ids).to include(job_postings(:sales_rep_published).id)
        expect(posting_ids).not_to include(job_postings(:marketing_manager_draft).id)
        expect(posting_ids).not_to include(job_postings(:devops_engineer_link_only).id)
      end

      it 'filters by status=draft' do
        get '/api/v1/job_postings', headers: headers, params: { status: 'draft' }

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        statuses = json['data'].map { |p| p['attributes']['status'] }

        # All postings should be draft
        expect(statuses).to all(eq('draft'))

        # Verify specific postings
        posting_ids = json['data'].map { |p| p['id'].to_i }
        expect(posting_ids).to include(job_postings(:marketing_manager_draft).id)
        expect(posting_ids).to include(job_postings(:frontend_engineer_draft).id)
        expect(posting_ids).not_to include(job_postings(:backend_engineer_published).id)
      end

      it 'filters by status=link_only' do
        get '/api/v1/job_postings', headers: headers, params: { status: 'link_only' }

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        statuses = json['data'].map { |p| p['attributes']['status'] }

        # All postings should be link_only
        expect(statuses).to all(eq('link_only'))

        # Verify specific postings
        posting_ids = json['data'].map { |p| p['id'].to_i }
        expect(posting_ids).to include(job_postings(:devops_engineer_link_only).id)
      end

      it 'filters by status=unpublished' do
        get '/api/v1/job_postings', headers: headers, params: { status: 'unpublished' }

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        statuses = json['data'].map { |p| p['attributes']['status'] }

        # All postings should be unpublished
        expect(statuses).to all(eq('unpublished'))

        # Verify specific postings
        posting_ids = json['data'].map { |p| p['id'].to_i }
        expect(posting_ids).to include(job_postings(:data_analyst_unpublished).id)
        expect(posting_ids).to include(job_postings(:product_manager_unpublished).id)
      end
    end

    # -------------------------------------------------------------------------
    # FILTERING TESTS - BY LOCATION
    # -------------------------------------------------------------------------
    # PURPOSE: Test filtering by location_id parameter
    # EXPECTATION: ?location_id=1 returns only postings at that location

    context 'with location filter' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'filters by location_id (HQ)' do
        location_id = locations(:acme_hq).id
        get '/api/v1/job_postings', headers: headers, params: { location_id: location_id }

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        posting_ids = json['data'].map { |p| p['id'].to_i }

        # Should include HQ postings
        expect(posting_ids).to include(job_postings(:backend_engineer_published).id)
        expect(posting_ids).to include(job_postings(:customer_support_published).id)

        # Should NOT include Remote postings
        expect(posting_ids).not_to include(job_postings(:sales_rep_published).id)
      end

      it 'filters by location_id (Remote)' do
        location_id = locations(:acme_remote).id
        get '/api/v1/job_postings', headers: headers, params: { location_id: location_id }

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        posting_ids = json['data'].map { |p| p['id'].to_i }

        # Should include Remote postings
        expect(posting_ids).to include(job_postings(:sales_rep_published).id)

        # Should NOT include HQ postings
        expect(posting_ids).not_to include(job_postings(:backend_engineer_published).id)
      end
    end

    # -------------------------------------------------------------------------
    # COMBINED FILTERING TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Test multiple filters together
    # EXPECTATION: ?status=published&location_id=1 returns published postings at HQ

    context 'with combined filters' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'filters by status and location' do
        location_id = locations(:acme_hq).id
        get '/api/v1/job_postings', headers: headers, params: { status: 'published', location_id: location_id }

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        posting_ids = json['data'].map { |p| p['id'].to_i }

        # Should include published HQ postings
        expect(posting_ids).to include(job_postings(:backend_engineer_published).id)
        expect(posting_ids).to include(job_postings(:customer_support_published).id)

        # Should NOT include draft HQ postings
        expect(posting_ids).not_to include(job_postings(:marketing_manager_draft).id)

        # Should NOT include published Remote postings
        expect(posting_ids).not_to include(job_postings(:sales_rep_published).id)
      end
    end

    # -------------------------------------------------------------------------
    # ORDERING TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Test default ordering (recent first)
    # EXPECTATION: Postings ordered by published_at DESC

    context 'ordering' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'orders postings by most recent published_at first' do
        get '/api/v1/job_postings', headers: headers, params: { status: 'published' }

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        published_dates = json['data'].map { |p| p['attributes']['published_at'] }

        # Dates should be in descending order (most recent first)
        expect(published_dates).to eq(published_dates.sort.reverse)
      end
    end

    # -------------------------------------------------------------------------
    # HIRING MANAGER ACCESS TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Verify hiring managers can also list postings
    # EXPECTATION: Hiring managers have same access as admins

    context 'with authenticated hiring manager' do
      let(:headers) { auth_headers(users(:acme_hiring_manager)) }

      it 'allows hiring manager to list postings' do
        get '/api/v1/job_postings', headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['data']).to be_an(Array)
        expect(json['data'].length).to be > 0
      end
    end
  end

  # =============================================================================
  # T078: PATCH /api/v1/job_postings/:id (UPDATE with STATUS TRANSITIONS)
  # =============================================================================
  # PURPOSE: Test updating job postings and status transitions
  # SECURITY LAYERS:
  # 1. Authentication: Requires valid JWT token
  # 2. Authorization: Admin or Hiring Manager only
  # 3. Brand Scoping: Only update postings from user's brand

  describe 'PATCH /api/v1/job_postings/:id' do
    # -------------------------------------------------------------------------
    # AUTHENTICATION TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Verify JWT authentication is enforced

    context 'without authentication' do
      let(:headers) { non_auth_headers }

      it 'returns 401 unauthorized' do
        posting = job_postings(:backend_engineer_published)
        patch "/api/v1/job_postings/#{posting.id}", headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    # -------------------------------------------------------------------------
    # AUTHORIZATION TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Verify only admins and hiring managers can update postings

    context 'with interviewer role (unauthorized)' do
      let(:headers) { auth_headers(users(:acme_interviewer)) }

      it 'returns 403 forbidden' do
        posting = job_postings(:backend_engineer_published)
        patch "/api/v1/job_postings/#{posting.id}",
              params: { job_posting: { job_title: 'Updated Title' } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')
        expect(response).to have_http_status(:forbidden)
      end
    end

    # -------------------------------------------------------------------------
    # BASIC UPDATE TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Test updating posting attributes
    # EXPECTATION: Can update job_title, description, requirements

    context 'with authenticated admin' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'updates job_title' do
        posting = job_postings(:backend_engineer_published)
        new_title = 'Updated Backend Engineer Title'

        patch "/api/v1/job_postings/#{posting.id}",
              params: { job_posting: { job_title: new_title } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['data']['attributes']['job_title']).to eq(new_title)

        posting.reload
        expect(posting.job_title).to eq(new_title)
      end

      it 'updates description and requirements' do
        posting = job_postings(:backend_engineer_published)
        new_description = 'Updated job description'
        new_requirements = 'Updated requirements'

        patch "/api/v1/job_postings/#{posting.id}",
              params: { job_posting: { description: new_description, requirements: new_requirements } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:ok)

        posting.reload
        expect(posting.description).to eq(new_description)
        expect(posting.requirements).to eq(new_requirements)
      end
    end

    # -------------------------------------------------------------------------
    # STATUS TRANSITION TESTS - PUBLISH!
    # -------------------------------------------------------------------------
    # PURPOSE: Test publishing a draft posting via API
    # EXPECTATION: PATCH with status: "published" triggers publish! event

    context 'status transitions - publish!' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'publishes a draft posting' do
        posting = job_postings(:marketing_manager_draft)
        expect(posting.status).to eq('draft')
        expect(posting.published_at).to be_nil

        patch "/api/v1/job_postings/#{posting.id}",
              params: { job_posting: { status: 'published' } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('published')
        expect(json['data']['attributes']['published_at']).to be_present

        posting.reload
        expect(posting.status).to eq('published')
        expect(posting.published_at).to be_present
      end

      it 'publishes a link_only posting' do
        posting = job_postings(:devops_engineer_link_only)
        expect(posting.status).to eq('link_only')

        patch "/api/v1/job_postings/#{posting.id}",
              params: { job_posting: { status: 'published' } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:ok)

        posting.reload
        expect(posting.status).to eq('published')
      end

      it 'returns error for invalid transition (unpublished → published)' do
        posting = job_postings(:data_analyst_unpublished)
        expect(posting.status).to eq('unpublished')

        patch "/api/v1/job_postings/#{posting.id}",
              params: { job_posting: { status: 'published' } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json).to have_key('error')
        expect(json['error']).to include('transition')

        posting.reload
        expect(posting.status).to eq('unpublished') # Status unchanged
      end
    end

    # -------------------------------------------------------------------------
    # STATUS TRANSITION TESTS - UNPUBLISH!
    # -------------------------------------------------------------------------
    # PURPOSE: Test unpublishing a posting via API
    # EXPECTATION: PATCH with status: "unpublished" triggers unpublish! event

    context 'status transitions - unpublish!' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'unpublishes a published posting' do
        posting = job_postings(:backend_engineer_published)
        expect(posting.status).to eq('published')
        expect(posting.unpublished_at).to be_nil

        patch "/api/v1/job_postings/#{posting.id}",
              params: { job_posting: { status: 'unpublished' } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('unpublished')
        expect(json['data']['attributes']['unpublished_at']).to be_present

        posting.reload
        expect(posting.status).to eq('unpublished')
        expect(posting.unpublished_at).to be_present
      end

      it 'unpublishes a link_only posting' do
        posting = job_postings(:devops_engineer_link_only)
        expect(posting.status).to eq('link_only')

        patch "/api/v1/job_postings/#{posting.id}",
              params: { job_posting: { status: 'unpublished' } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:ok)

        posting.reload
        expect(posting.status).to eq('unpublished')
      end

      it 'returns error for invalid transition (draft → unpublished)' do
        posting = job_postings(:marketing_manager_draft)
        expect(posting.status).to eq('draft')

        patch "/api/v1/job_postings/#{posting.id}",
              params: { job_posting: { status: 'unpublished' } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json).to have_key('error')

        posting.reload
        expect(posting.status).to eq('draft') # Status unchanged
      end
    end

    # -------------------------------------------------------------------------
    # STATUS TRANSITION TESTS - MAKE_LINK_ONLY!
    # -------------------------------------------------------------------------
    # PURPOSE: Test changing posting to link-only via API
    # EXPECTATION: PATCH with status: "link_only" triggers make_link_only! event

    context 'status transitions - make_link_only!' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'changes published posting to link_only' do
        posting = job_postings(:backend_engineer_published)
        expect(posting.status).to eq('published')

        patch "/api/v1/job_postings/#{posting.id}",
              params: { job_posting: { status: 'link_only' } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('link_only')

        posting.reload
        expect(posting.status).to eq('link_only')
      end

      it 'returns error for invalid transition (draft → link_only)' do
        posting = job_postings(:marketing_manager_draft)
        expect(posting.status).to eq('draft')

        patch "/api/v1/job_postings/#{posting.id}",
              params: { job_posting: { status: 'link_only' } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json).to have_key('error')

        posting.reload
        expect(posting.status).to eq('draft') # Status unchanged
      end
    end

    # -------------------------------------------------------------------------
    # COMBINED UPDATE TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Test updating attributes AND changing status
    # EXPECTATION: Both updates should succeed

    context 'combined attribute and status updates' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'updates attributes and publishes in single request' do
        posting = job_postings(:marketing_manager_draft)
        new_title = 'Senior Product Marketing Manager'

        patch "/api/v1/job_postings/#{posting.id}",
              params: { job_posting: { job_title: new_title, status: 'published' } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:ok)

        posting.reload
        expect(posting.job_title).to eq(new_title)
        expect(posting.status).to eq('published')
      end
    end

    # -------------------------------------------------------------------------
    # BRAND SCOPING TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Verify users cannot update postings from other brands
    # EXPECTATION: 404 when trying to access Globex posting from Acme user

    context 'brand scoping' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'prevents updating postings from other brands' do
        globex_posting = job_postings(:globex_engineer_published)

        patch "/api/v1/job_postings/#{globex_posting.id}",
              params: { job_posting: { job_title: 'Hacked Title' } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        # Brand scoping prevents access - returns 404 (RecordNotFound is caught by rescue_from)
        expect(response).to have_http_status(:not_found)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('Resource not found')
      end
    end

    # -------------------------------------------------------------------------
    # HIRING MANAGER ACCESS TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Verify hiring managers can update postings
    # EXPECTATION: Hiring managers have same access as admins

    context 'with authenticated hiring manager' do
      let(:headers) { auth_headers(users(:acme_hiring_manager)) }

      it 'allows hiring manager to update postings' do
        posting = job_postings(:backend_engineer_published)
        new_title = 'Updated by Hiring Manager'

        patch "/api/v1/job_postings/#{posting.id}",
              params: { job_posting: { job_title: new_title } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:ok)

        posting.reload
        expect(posting.job_title).to eq(new_title)
      end

      it 'allows hiring manager to transition status' do
        posting = job_postings(:marketing_manager_draft)

        patch "/api/v1/job_postings/#{posting.id}",
              params: { job_posting: { status: 'published' } }.to_json,
              headers: headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:ok)

        posting.reload
        expect(posting.status).to eq('published')
      end
    end
  end

  # =============================================================================
  # GET /api/v1/job_postings/:id (SHOW)
  # =============================================================================
  # PURPOSE: Test fetching a single job posting
  # SECURITY: Same authentication/authorization as index

  describe 'GET /api/v1/job_postings/:id' do
    context 'with authenticated admin' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'returns a single job posting' do
        posting = job_postings(:backend_engineer_published)

        get "/api/v1/job_postings/#{posting.id}", headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['data']['id']).to eq(posting.id.to_s)
        expect(json['data']['attributes']['job_title']).to eq(posting.job_title)
      end
    end
  end
end
