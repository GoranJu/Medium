# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SamlProvidersController, feature_category: :system_access do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)

    stub_licensed_features(group_saml: true)
  end

  describe 'GET group_saml_providers' do
    subject(:get_group_saml_providers) { get group_saml_providers_path(group) }

    before_all do
      group.add_owner(user)
    end

    before do
      create(:saml_provider, group: group)
    end

    it 'initializes microsoft application from SystemAccess::MicrosoftApplication' do
      create(:system_access_group_microsoft_application, group: group, client_xid: 'test-xid-123')
      create(:system_access_microsoft_application, namespace: group, client_xid: 'test-xid-456')

      get_group_saml_providers

      expect(response.body).to match(/test-xid-456/)
    end
  end

  describe 'PUT update_microsoft_application' do
    context 'when SAML SSO is not enabled' do
      it 'renders 404 not found' do
        put update_microsoft_application_group_saml_providers_path(group)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when SAML SSO is enabled' do
      before do
        create(:saml_provider, group: group)
      end

      context 'when the user is not a group owner' do
        it 'renders 404 not found' do
          put update_microsoft_application_group_saml_providers_path(group)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the user is a group owner' do
        let(:params) do
          { system_access_microsoft_application: attributes_for(:system_access_group_microsoft_application) }
        end

        let(:path) { update_microsoft_application_group_saml_providers_path(group) }

        subject(:update_request) { put path, params: params }

        before_all do
          group.add_owner(user)
        end

        it_behaves_like 'Microsoft application controller actions'

        it 'creates new SystemAccess::GroupMicrosoftApplication' do
          expect { update_request }.to change { SystemAccess::GroupMicrosoftApplication.count }.by(1)
        end

        it 'also writes to legacy SystemAccess::MicrosoftApplication table' do
          expect { update_request }.to change { SystemAccess::GroupMicrosoftApplication.count }.by(1).and(
            change { SystemAccess::MicrosoftApplication.count }.by(1)
          )
        end
      end
    end
  end
end
