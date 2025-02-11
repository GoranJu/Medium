# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemAccess::GroupMicrosoftApplication, type: :model, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:group) }

    it 'has one graph_access_token' do
      token = create(:system_access_group_microsoft_graph_access_token)
      app = build_stubbed(:system_access_group_microsoft_application, graph_access_token: token)

      expect(app.graph_access_token).to eql(token)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:tenant_xid) }
    it { is_expected.to validate_presence_of(:client_xid) }
    it { is_expected.to validate_presence_of(:encrypted_client_secret) }
    it { is_expected.to validate_presence_of(:login_endpoint) }
    it { is_expected.to validate_presence_of(:graph_endpoint) }

    context 'when validating login_endpoint' do
      it 'is invalid if not an https URL' do
        app = build(:system_access_group_microsoft_application, login_endpoint: 'http://example.com')
        expect(app).not_to be_valid
        expect(app.errors[:login_endpoint]).to include('is blocked: Only allowed schemes are https')
      end

      it 'is valid with an https URL' do
        app = build(:system_access_group_microsoft_application, login_endpoint: 'https://example.com')
        expect(app).to be_valid
      end
    end

    context 'when validating graph_endpoint' do
      it 'is invalid if not an https URL' do
        app = build(:system_access_group_microsoft_application, graph_endpoint: 'http://example.com')
        expect(app).not_to be_valid
        expect(app.errors[:graph_endpoint]).to include('is blocked: Only allowed schemes are https')
      end

      it 'is valid with an https URL' do
        app = build(:system_access_group_microsoft_application, graph_endpoint: 'https://example.com')
        expect(app).to be_valid
      end
    end
  end
end
