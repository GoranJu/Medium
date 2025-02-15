# frozen_string_literal: true

RSpec.shared_examples 'projects graphql query with SAML session filtering' do
  include GraphqlHelpers

  let_it_be(:saml_provider) { create(:saml_provider) }
  let_it_be(:saml_group) do
    create(:group, saml_provider: saml_provider, developers: current_user) do |group|
      create(:group_saml_identity, saml_provider: group.saml_provider, user: current_user)
    end
  end

  let_it_be(:saml_project) { create(:project, group: saml_group, developers: current_user) }

  context 'when current user has an active SAML session' do
    before do
      active_saml_sessions = { saml_group.saml_provider.id => Time.current }
      allow(::Gitlab::Auth::GroupSaml::SsoState).to receive(:active_saml_sessions).and_return(active_saml_sessions)
    end

    it 'includes SAML project' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at(*path)).to include(a_graphql_entity_for(saml_project))
    end
  end

  context 'when current user has no active SAML session' do
    it 'excludes SAML project' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at(*path)).not_to include(a_graphql_entity_for(saml_project))
    end
  end
end
