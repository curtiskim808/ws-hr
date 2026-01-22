require 'rails_helper'

RSpec.describe JwtDenylist, type: :model do
  describe 'configuration' do
    it 'uses the jwt_denylists table' do
      expect(described_class.table_name).to eq('jwt_denylists')
    end
  end

  describe 'jwt revocation strategy' do
    let(:exp_timestamp) { 2.hours.from_now.to_i }
    let(:payload) { { 'jti' => 'token-123', 'exp' => exp_timestamp } }

    it 'revokes a token by storing its jti and exp' do
      described_class.revoke_jwt(payload, nil)

      record = described_class.find_by(jti: payload['jti'])
      expect(record).to be_present
      expect(record.exp.to_i).to be_within(1).of(exp_timestamp)
    end

    it 'marks a stored token as revoked' do
      described_class.revoke_jwt(payload, nil)

      expect(described_class.jwt_revoked?(payload, nil)).to be(true)
    end

    it 'does not mark unknown tokens as revoked' do
      expect(described_class.jwt_revoked?(payload, nil)).to be(false)
    end
  end
end
