# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::RemoteDevelopment::NamespaceClusterAgentMappingOperations::Delete::Main, feature_category: :workspaces do
  let_it_be(:namespace_cluster_agent_mapping) do
    create(:remote_development_namespace_cluster_agent_mapping)
  end

  subject(:response) do
    described_class.main(
      namespace: namespace_cluster_agent_mapping.namespace,
      cluster_agent: namespace_cluster_agent_mapping.agent
    )
  end

  context 'when params are valid' do
    it 'deletes an existing mapping for a given namespace and cluster_agent' do
      expect { response }.to change { RemoteDevelopment::RemoteDevelopmentNamespaceClusterAgentMapping.count }.by(-1)

      expect(response.fetch(:status)).to eq(:success)
      expect(response[:message]).to be_nil
      expect(response[:payload]).to be_empty
    end
  end

  context 'when params are invalid' do
    context 'when a mapping does not exist for a given namespace and cluster agent' do
      let(:namespace_cluster_agent_mapping) do
        build(:remote_development_namespace_cluster_agent_mapping)
      end

      it 'does not create the mapping and returns an error' do
        expect { response }.not_to change { RemoteDevelopment::RemoteDevelopmentNamespaceClusterAgentMapping.count }

        expect(response).to eq({
          status: :error,
          message: "Namespace cluster agent mapping not found",
          reason: :bad_request
        })
      end
    end
  end
end
