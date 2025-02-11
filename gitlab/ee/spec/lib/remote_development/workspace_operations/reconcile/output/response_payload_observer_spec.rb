# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Output::ResponsePayloadObserver, feature_category: :workspaces do
  let(:agent) { instance_double("Clusters::Agent", id: 1) } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  let(:update_type) { RemoteDevelopment::WorkspaceOperations::Reconcile::UpdateTypes::PARTIAL }
  let(:desired_state) { RemoteDevelopment::WorkspaceOperations::States::RUNNING }
  let(:actual_state) { RemoteDevelopment::WorkspaceOperations::States::STOPPED }
  let(:logger) { instance_double(::Logger) }

  let(:workspace_rails_infos) do
    [
      {
        name: "workspace1",
        namespace: "namespace1",
        deployment_resource_version: "1",
        desired_state: desired_state,
        actual_state: actual_state,
        config_to_apply: :does_not_matter_should_not_be_logged
      },
      {
        name: "workspace2",
        namespace: "namespace2",
        deployment_resource_version: "2",
        desired_state: desired_state,
        actual_state: actual_state,
        config_to_apply: :does_not_matter_should_not_be_logged
      }
    ]
  end

  let(:expected_logged_workspace_rails_infos) do
    [
      {
        name: "workspace1",
        namespace: "namespace1",
        deployment_resource_version: "1",
        desired_state: desired_state,
        actual_state: actual_state
      },
      {
        name: "workspace2",
        namespace: "namespace2",
        deployment_resource_version: "2",
        desired_state: desired_state,
        actual_state: actual_state
      }
    ]
  end

  let(:expected_observability_for_rails_infos) do
    {
      workspace1: {
        config_to_apply_resources_included: "no_resources_included"
      },
      workspace2: {
        config_to_apply_resources_included: "partial_resources_included"
      }
    }
  end

  let(:context) do
    {
      agent: agent,
      update_type: update_type,
      response_payload: {
        workspace_rails_infos: workspace_rails_infos,
        settings: {
          full_reconciliation_interval_seconds: 3600,
          partial_reconciliation_interval_seconds: 10
        }
      },
      observability_for_rails_infos: expected_observability_for_rails_infos,
      logger: logger
    }
  end

  subject(:returned_value) do
    described_class.observe(context)
  end

  it "logs workspace_rails_infos", :unlimited_max_formatted_output_length do
    expect(logger).to receive(:debug).with(
      message: 'Returning verified response_payload',
      agent_id: agent.id,
      update_type: update_type,
      response_payload: {
        workspace_rails_info_count: workspace_rails_infos.length,
        workspace_rails_infos: expected_logged_workspace_rails_infos,
        settings: {
          full_reconciliation_interval_seconds: 3600,
          partial_reconciliation_interval_seconds: 10
        }
      },
      observability_for_rails_infos: expected_observability_for_rails_infos
    )

    expect(returned_value).to eq(context)
  end
end
