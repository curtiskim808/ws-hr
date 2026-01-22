# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Applicants API', type: :request do
  fixtures :brands,
           :users,
           :applicants,
           :applications,
           :job_postings,
           :hiring_processes,
           :hiring_stages,
           :position_templates,
           :locations

  describe 'GET /api/v1/applicants' do
    context 'without authentication' do
      let(:headers) { non_auth_headers }

      it 'returns 401 unauthorized' do
        get '/api/v1/applicants', headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with authenticated acme admin' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'returns only applicants from the current brand' do
        get '/api/v1/applicants', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        applicant_ids = json['data'].map { |applicant| applicant['id'].to_i }

        expect(applicant_ids).to include(applicants(:john_doe).id)
        expect(applicant_ids).to include(applicants(:flagged_applicant).id)
        expect(applicant_ids).not_to include(applicants(:globex_applicant).id)
      end

      it 'filters by source' do
        get '/api/v1/applicants?source=linkedin', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        sources = json['data'].map { |applicant| applicant['attributes']['source'] }

        expect(sources).to all(eq('linkedin'))
      end

      it 'filters flagged applicants' do
        get '/api/v1/applicants?flagged=true', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        flagged = json['data'].map { |applicant| applicant['attributes']['flagged'] }

        expect(flagged).to all(be(true))
      end

      it 'returns JSON:API formatted data' do
        get '/api/v1/applicants', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json).to have_key('data')
        expect(json['data']).to be_an(Array)

        sample = json['data'].first
        expect(sample).to have_key('id')
        expect(sample).to have_key('type')
        expect(sample).to have_key('attributes')
        expect(sample['type']).to eq('applicant')
      end
    end
  end

  describe 'GET /api/v1/applicants/:id' do
    let(:headers) { auth_headers(users(:acme_admin)) }

    it 'returns applicant details with applications included' do
      applicant = applicants(:john_doe)
      get "/api/v1/applicants/#{applicant.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['data']['id']).to eq(applicant.id.to_s)
      expect(json['data']['type']).to eq('applicant')
      expect(json['data']['attributes']['full_name']).to eq(applicant.full_name)

      included_ids = json['included'].map { |item| item['id'].to_i }
      expect(included_ids).to include(applications(:pending_application).id)
    end

    it 'returns 404 for cross-brand access' do
      get "/api/v1/applicants/#{applicants(:globex_applicant).id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/applicants' do
    let(:payload) do
      {
        applicant: {
          first_name: 'Chris',
          last_name: 'Rivers',
          email: 'chris.rivers@example.com',
          phone: '+1-555-5555',
          source: 'referral'
        }
      }.to_json
    end

    context 'with admin user' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'creates a new applicant' do
        expect {
          post '/api/v1/applicants', params: payload, headers: headers
        }.to change(Applicant, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['data']['type']).to eq('applicant')
        expect(Applicant.last.brand_id).to eq(users(:acme_admin).brand_id)
      end
    end

    context 'with interviewer user' do
      let(:headers) { auth_headers(users(:acme_interviewer)) }

      it 'returns 403 forbidden' do
        post '/api/v1/applicants', params: payload, headers: headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with invalid params' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'returns 422 with validation errors' do
        invalid_payload = { applicant: { last_name: 'MissingFirst', email: 'bad' } }.to_json
        post '/api/v1/applicants', params: invalid_payload, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to have_key('first_name')
        expect(json['errors']).to have_key('email')
      end
    end
  end

  describe 'PATCH /api/v1/applicants/:id' do
    let(:applicant) { applicants(:john_doe) }
    let(:payload) do
      {
        applicant: {
          flagged: true,
          flag_reason: 'Duplicate application detected'
        }
      }.to_json
    end

    context 'with hiring manager user' do
      let(:headers) { auth_headers(users(:acme_hiring_manager)) }

      it 'updates the applicant' do
        patch "/api/v1/applicants/#{applicant.id}", params: payload, headers: headers

        expect(response).to have_http_status(:ok)
        expect(applicant.reload.flagged).to be(true)
        expect(applicant.flag_reason).to eq('Duplicate application detected')
      end
    end

    context 'with interviewer user' do
      let(:headers) { auth_headers(users(:acme_interviewer)) }

      it 'returns 403 forbidden' do
        patch "/api/v1/applicants/#{applicant.id}", params: payload, headers: headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with invalid params' do
      let(:headers) { auth_headers(users(:acme_admin)) }

      it 'returns 422 with validation errors' do
        invalid_payload = { applicant: { phone: 'invalid-phone' } }.to_json
        patch "/api/v1/applicants/#{applicant.id}", params: invalid_payload, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to have_key('phone')
      end
    end
  end
end
