# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Project settings update", feature_category: :code_suggestions do
  include GraphqlHelpers
  include ProjectForksHelper
  include ExclusiveLeaseHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :gitlab_duo_pro) }
  let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:duo_features_enabled) { true }

  let(:mutation) do
    params = { full_path: project.full_path, duo_features_enabled: duo_features_enabled }

    graphql_mutation(:project_settings_update, params) do
      <<-QL.strip_heredoc
        projectSettings {
          duoFeaturesEnabled
        }
        errors
      QL
    end
  end

  context 'when updating settings' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_saas_features(duo_chat_on_saas: true)
    end

    it 'will update the settings' do
      post_graphql_mutation(mutation, current_user: user)
      expect(graphql_mutation_response('projectSettingsUpdate')['projectSettings'])
               .to eq({ 'duoFeaturesEnabled' => duo_features_enabled })
    end
  end
end
