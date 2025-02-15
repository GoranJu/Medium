# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting organization information', feature_category: :cell do
  include ::GraphqlHelpers

  let(:query) { graphql_query_for(:organization, { id: organization.to_global_id }, organization_fields) }

  let_it_be(:organization_owner) { create(:organization_owner) }
  let_it_be(:organization) { organization_owner.organization }
  let_it_be(:current_user) { organization_owner.user }
  let_it_be(:group) { create(:group, organization: organization, developers: current_user) }
  let_it_be(:project) { create(:project, group: group, organization: organization, developers: current_user) }

  subject(:request_organization) { post_graphql(query, current_user: current_user) }

  context 'when requesting groups' do
    let_it_be(:saml_group) do
      create(:group, organization: organization, developers: current_user) do |group|
        create(:saml_provider, group: group)
        create(:group_saml_identity, saml_provider: group.saml_provider, user: current_user)
      end
    end

    let(:groups) { graphql_data_at(:organization, :groups, :nodes) }
    let(:organization_fields) do
      <<~FIELDS
        groups(first: 1, sort: "id_desc") {
          nodes {
            id
          }
        }
      FIELDS
    end

    context 'when current user has an active SAML session' do
      before do
        active_saml_sessions = { saml_group.saml_provider.id => Time.current }
        allow(::Gitlab::Auth::GroupSaml::SsoState).to receive(:active_saml_sessions).and_return(active_saml_sessions)
      end

      it 'includes SAML groups' do
        request_organization

        expect(groups).to contain_exactly(a_graphql_entity_for(saml_group))
      end
    end

    context 'when current user has no active SAML session' do
      it 'excludes SAML group' do
        request_organization

        expect(groups).to contain_exactly(a_graphql_entity_for(group))
      end
    end
  end
end
