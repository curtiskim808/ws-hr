# Applications API Request Spec - T116
#
# TESTING PHILOSOPHY:
# - Test the full request/response cycle (integration testing)
# - Test authentication, authorization, and brand scoping
# - Test JSON:API response format
# - Test error handling and validation
#
# KEY FEATURE:
# - POST /api/v1/applications is PUBLIC (no authentication required)
# - This allows candidates to apply for jobs without creating an account
#
# FIXTURE USAGE:
# - job_postings(:backend_engineer_published) - Published job for applications
# - users(:acme_admin) - Authorized user for authenticated endpoints
# - users(:acme_hiring_manager) - Authorized user
# - users(:acme_interviewer) - Limited access user
# - applicants(:john_doe) - Existing applicant
# - applications(:pending_application) - Existing application

require 'rails_helper'

RSpec.describe 'Applications API', type: :request do
  # SETUP: Load fixtures for all tests
  fixtures :brands, :users, :locations, :position_templates, :hiring_processes,
           :hiring_stages, :job_postings, :applicants, :applications

  # =============================================================================
  # T116: POST /api/v1/applications (PUBLIC APPLICATION SUBMISSION)
  # =============================================================================
  # PURPOSE: Test public application submission (no authentication required)
  # KEY POINT: This is the only endpoint that skips authentication
  # USE CASE: Candidates apply for jobs via public careers page

  describe 'POST /api/v1/applications' do
    let(:job_posting) { job_postings(:backend_engineer_published) }

    # Valid application payload
    let(:valid_params) do
      {
        job_posting_id: job_posting.id,
        applicant: {
          first_name: 'New',
          last_name: 'Applicant',
          email: 'new.applicant@example.com',
          phone: '+1-555-9999',
          source: 'careers_page'
        },
        notes: 'Very interested in this position'
      }
    end

    # -------------------------------------------------------------------------
    # PUBLIC ACCESS TESTS
    # -------------------------------------------------------------------------
    # PURPOSE: Verify no authentication is required

    context 'without authentication (public endpoint)' do
      it 'creates application successfully' do
        expect {
          post '/api/v1/applications',
               params: valid_params.to_json,
               headers: { 'Content-Type' => 'application/json' }
        }.to change(Application, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it 'creates applicant if not exists' do
        expect {
          post '/api/v1/applications',
               params: valid_params.to_json,
               headers: { 'Content-Type' => 'application/json' }
        }.to change(Applicant.unscoped, :count).by(1)
      end

      it 'returns application in JSON:API format' do
        post '/api/v1/applications',
             params: valid_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to have_key('id')
        expect(json['data']['type']).to eq('application')
        expect(json['data']['attributes']).to have_key('status')
        expect(json['data']['attributes']['status']).to eq('in_progress')
      end

      it 'sets brand from job_posting' do
        post '/api/v1/applications',
             params: valid_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        application = Application.unscoped.last
        expect(application.brand_id).to eq(job_posting.brand_id)
      end

      it 'sets hiring_process from job_posting' do
        post '/api/v1/applications',
             params: valid_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        application = Application.unscoped.last
        expect(application.hiring_process_id).to eq(job_posting.hiring_process_id)
      end

      it 'sets applied_at timestamp' do
        freeze_time do
          post '/api/v1/applications',
               params: valid_params.to_json,
               headers: { 'Content-Type' => 'application/json' }

          application = Application.unscoped.last
          expect(application.applied_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    # -------------------------------------------------------------------------
    # FIND OR CREATE APPLICANT
    # -------------------------------------------------------------------------
    # PURPOSE: Test applicant reuse when email already exists

    context 'when applicant email already exists in brand' do
      let(:existing_params) do
        {
          job_posting_id: job_postings(:sales_rep_published).id,  # Different job
          applicant: {
            first_name: 'John',
            last_name: 'Doe',
            email: 'john.doe@example.com',  # Same email as john_doe fixture
            phone: '+1-555-0100',
            source: 'linkedin'
          }
        }
      end

      it 'reuses existing applicant' do
        expect {
          post '/api/v1/applications',
               params: existing_params.to_json,
               headers: { 'Content-Type' => 'application/json' }
        }.not_to change(Applicant.unscoped, :count)

        expect(response).to have_http_status(:created)
      end

      it 'links application to existing applicant' do
        post '/api/v1/applications',
             params: existing_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        application = Application.unscoped.last
        expect(application.applicant_id).to eq(applicants(:john_doe).id)
      end
    end

    # -------------------------------------------------------------------------
    # DUPLICATE APPLICATION PREVENTION
    # -------------------------------------------------------------------------
    # PURPOSE: Test that same applicant can't apply twice to same job

    context 'when applicant already applied to this job' do
      # john_doe already has pending_application to backend_engineer_published
      let(:duplicate_params) do
        {
          job_posting_id: job_postings(:backend_engineer_published).id,
          applicant: {
            first_name: 'John',
            last_name: 'Doe',
            email: 'john.doe@example.com',
            phone: '+1-555-0100',
            source: 'careers_page'
          }
        }
      end

      it 'returns 422 unprocessable entity' do
        post '/api/v1/applications',
             params: duplicate_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error message about duplicate' do
        post '/api/v1/applications',
             params: duplicate_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        json = JSON.parse(response.body)
        expect(json['error']).to eq('Validation failed')
        expect(json['errors']['applicant_id']).to include('has already applied to this job posting')
      end

      it 'does not create new application' do
        expect {
          post '/api/v1/applications',
               params: duplicate_params.to_json,
               headers: { 'Content-Type' => 'application/json' }
        }.not_to change(Application.unscoped, :count)
      end
    end

    # -------------------------------------------------------------------------
    # VALIDATION ERRORS
    # -------------------------------------------------------------------------
    # PURPOSE: Test validation error handling

    context 'with missing required fields' do
      let(:invalid_params) do
        {
          job_posting_id: job_posting.id,
          applicant: {
            first_name: '',  # Empty
            last_name: 'Applicant',
            email: ''  # Empty
          }
        }
      end

      it 'returns 422 unprocessable entity' do
        post '/api/v1/applications',
             params: invalid_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors' do
        post '/api/v1/applications',
             params: invalid_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        json = JSON.parse(response.body)
        expect(json['error']).to eq('Validation failed')
        expect(json['errors']).to be_present
      end
    end

    context 'with invalid email format' do
      let(:invalid_email_params) do
        {
          job_posting_id: job_posting.id,
          applicant: {
            first_name: 'Test',
            last_name: 'User',
            email: 'invalid-email'
          }
        }
      end

      it 'returns validation error for email' do
        post '/api/v1/applications',
             params: invalid_email_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']['email']).to include('must be a valid email address')
      end
    end

    context 'with non-existent job_posting_id' do
      let(:invalid_job_params) do
        {
          job_posting_id: 999999,
          applicant: {
            first_name: 'Test',
            last_name: 'User',
            email: 'test@example.com'
          }
        }
      end

      it 'returns 404 not found' do
        post '/api/v1/applications',
             params: invalid_job_params.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # =============================================================================
  # GET /api/v1/applications (INDEX)
  # =============================================================================
  # PURPOSE: Test listing applications with filtering
  # AUTHENTICATION: Required

  describe 'GET /api/v1/applications' do
    context 'without authentication' do
      it 'returns 401 unauthorized' do
        get '/api/v1/applications', headers: non_auth_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with authenticated admin' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'returns applications from user brand only' do
        get '/api/v1/applications', headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        application_ids = json['data'].map { |a| a['id'].to_i }

        # Should include Acme applications
        expect(application_ids).to include(applications(:pending_application).id)

        # Should NOT include Globex applications
        globex_app = Application.unscoped.find_by(brand: brands(:globex))
        expect(application_ids).not_to include(globex_app.id) if globex_app
      end

      it 'returns applications in JSON:API format' do
        get '/api/v1/applications', headers: headers

        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)

        first = json['data'].first
        expect(first).to have_key('id')
        expect(first['type']).to eq('application')
        expect(first['attributes']).to have_key('status')
      end
    end

    context 'with status filter' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'filters by in_progress status' do
        get '/api/v1/applications', params: { status: 'in_progress' }, headers: headers

        json = JSON.parse(response.body)
        statuses = json['data'].map { |a| a['attributes']['status'] }.uniq

        expect(statuses).to eq(['in_progress'])
      end

      it 'filters by hired status' do
        get '/api/v1/applications', params: { status: 'hired' }, headers: headers

        json = JSON.parse(response.body)
        statuses = json['data'].map { |a| a['attributes']['status'] }.uniq

        expect(statuses).to eq(['hired'])
      end
    end

    context 'with job_posting_id filter' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'filters by job posting' do
        job_posting = job_postings(:backend_engineer_published)
        get '/api/v1/applications',
            params: { job_posting_id: job_posting.id },
            headers: headers

        json = JSON.parse(response.body)
        # All returned applications should be for this job posting
        json['data'].each do |app_data|
          app = Application.unscoped.find(app_data['id'])
          expect(app.job_posting_id).to eq(job_posting.id)
        end
      end
    end
  end

  # =============================================================================
  # PATCH /api/v1/applications/:id (UPDATE / ACTIONS)
  # =============================================================================
  # PURPOSE: Test application updates and workflow actions
  # AUTHENTICATION: Required
  # AUTHORIZATION: Admin or Hiring Manager

  describe 'PATCH /api/v1/applications/:id' do
    let(:application) { applications(:pending_application) }

    context 'without authentication' do
      it 'returns 401 unauthorized' do
        patch "/api/v1/applications/#{application.id}",
              params: { action_type: 'hire' }.to_json,
              headers: non_auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with interviewer (unauthorized)' do
      let(:headers) { auth_headers(users(:acme_interviewer)) }

      it 'returns 403 forbidden' do
        patch "/api/v1/applications/#{application.id}",
              params: { action_type: 'hire' }.to_json,
              headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with hiring manager (authorized)' do
      let(:headers) { auth_headers(users(:acme_hiring_manager)) }

      describe 'action_type: hire' do
        let(:app_for_hire) { applications(:technical_interview_application) }

        it 'hires the applicant' do
          patch "/api/v1/applications/#{app_for_hire.id}",
                params: { action_type: 'hire' }.to_json,
                headers: headers

          expect(response).to have_http_status(:ok)

          json = JSON.parse(response.body)
          expect(json['data']['attributes']['status']).to eq('hired')
        end
      end

      describe 'action_type: reject' do
        it 'rejects the applicant with reason' do
          patch "/api/v1/applications/#{application.id}",
                params: {
                  action_type: 'reject',
                  rejection_reason: 'Not enough experience'
                }.to_json,
                headers: headers

          expect(response).to have_http_status(:ok)

          json = JSON.parse(response.body)
          expect(json['data']['attributes']['status']).to eq('rejected')
          expect(json['data']['attributes']['rejection_reason']).to eq('Not enough experience')
        end
      end

      describe 'action_type: advance_stage' do
        let(:phone_screen) { hiring_stages(:default_phone_screen) }

        it 'advances to specified stage' do
          patch "/api/v1/applications/#{application.id}",
                params: {
                  action_type: 'advance_stage',
                  stage_id: phone_screen.id,
                  notes: 'Strong candidate'
                }.to_json,
                headers: headers

          expect(response).to have_http_status(:ok)

          json = JSON.parse(response.body)
          expect(json['data']['attributes']['current_stage_name']).to eq('Phone Screen')
        end
      end

      describe 'regular update' do
        it 'updates notes' do
          patch "/api/v1/applications/#{application.id}",
                params: { application: { notes: 'Updated notes' } }.to_json,
                headers: headers

          expect(response).to have_http_status(:ok)

          json = JSON.parse(response.body)
          expect(json['data']['attributes']['notes']).to eq('Updated notes')
        end
      end
    end
  end

  # =============================================================================
  # DELETE /api/v1/applications/:id (ARCHIVE)
  # =============================================================================
  # PURPOSE: Test application archiving
  # AUTHENTICATION: Required
  # AUTHORIZATION: Admin or Hiring Manager

  describe 'DELETE /api/v1/applications/:id' do
    let(:application) { applications(:pending_application) }

    context 'without authentication' do
      it 'returns 401 unauthorized' do
        delete "/api/v1/applications/#{application.id}", headers: non_auth_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with hiring manager' do
      let(:headers) { auth_headers(users(:acme_hiring_manager)) }

      it 'archives the application' do
        delete "/api/v1/applications/#{application.id}", headers: headers

        expect(response).to have_http_status(:no_content)

        application.reload
        expect(application.archived?).to be true
      end
    end
  end
end
