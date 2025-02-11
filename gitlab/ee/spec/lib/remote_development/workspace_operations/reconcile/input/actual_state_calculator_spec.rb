# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ActualStateCalculator, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  describe '.calculate_actual_state' do
    subject(:actual_state_calculator) do
      described_class
    end

    context 'with cases parameterized from shared fixtures' do
      where(:previous_actual_state, :current_actual_state, :workspace_exists) do
        # rubocop:disable Layout/LineLength -- Keep table rows on single lines for readability
        [
          # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/409783
          #       These are currently taken from only the currently supported cases in
          #       remote_development_shared_contexts.rb#create_workspace_agent_info_hash,
          #       but we should ensure they are providing full and
          #       realistic coverage of all possible relevant states.
          #       Note that `nil` is passed when the argument will not be used by
          #       remote_development_shared_contexts.rb
          [RemoteDevelopment::WorkspaceOperations::States::CREATION_REQUESTED, RemoteDevelopment::WorkspaceOperations::States::STARTING, nil],
          [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::STARTING, false],
          [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::RUNNING, false],
          [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::FAILED, false],
          [RemoteDevelopment::WorkspaceOperations::States::FAILED, RemoteDevelopment::WorkspaceOperations::States::STARTING, false],
          [RemoteDevelopment::WorkspaceOperations::States::RUNNING, RemoteDevelopment::WorkspaceOperations::States::FAILED, nil],
          [RemoteDevelopment::WorkspaceOperations::States::RUNNING, RemoteDevelopment::WorkspaceOperations::States::STOPPING, nil],
          [RemoteDevelopment::WorkspaceOperations::States::STOPPING, RemoteDevelopment::WorkspaceOperations::States::STOPPED, nil],
          [RemoteDevelopment::WorkspaceOperations::States::STOPPING, RemoteDevelopment::WorkspaceOperations::States::FAILED, nil],
          [RemoteDevelopment::WorkspaceOperations::States::STOPPED, RemoteDevelopment::WorkspaceOperations::States::STARTING, nil],
          [RemoteDevelopment::WorkspaceOperations::States::STOPPED, RemoteDevelopment::WorkspaceOperations::States::STOPPED, true],
          [RemoteDevelopment::WorkspaceOperations::States::STOPPED, RemoteDevelopment::WorkspaceOperations::States::FAILED, nil],
          [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::STARTING, true],
          [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::RUNNING, true],
          [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::FAILED, true],
          [RemoteDevelopment::WorkspaceOperations::States::FAILED, RemoteDevelopment::WorkspaceOperations::States::STARTING, true],
          [RemoteDevelopment::WorkspaceOperations::States::FAILED, RemoteDevelopment::WorkspaceOperations::States::STOPPING, nil],
          [nil, RemoteDevelopment::WorkspaceOperations::States::FAILED, nil]
        ]
        # rubocop:enable Layout/LineLength
      end

      with_them do
        let(:agent) { instance_double("Clusters::Agent", id: 1) } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper

        let(:workspace) do
          instance_double(
            "RemoteDevelopment::Workspace", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
            id: 1, name: 'name', namespace: 'namespace', agent: agent,
            desired_config_generator_version:
              ::RemoteDevelopment::WorkspaceOperations::DesiredConfigGeneratorVersion::LATEST_VERSION
          )
        end

        let(:latest_k8s_deployment_info) do
          workspace_agent_info_hash = create_workspace_agent_info_hash(
            workspace: workspace,
            previous_actual_state: previous_actual_state,
            current_actual_state: current_actual_state,
            workspace_exists: workspace_exists,
            workspace_variables_environment: {},
            workspace_variables_file: {}
          )
          workspace_agent_info_hash.fetch(:latest_k8s_deployment_info).to_h
        end

        it 'calculates correct actual state' do
          calculated_actual_state = nil
          begin
            calculated_actual_state = actual_state_calculator.calculate_actual_state(
              latest_k8s_deployment_info: latest_k8s_deployment_info
            )
          rescue RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
            skip 'TODO: Properly implement the agent info status fixture for ' \
              "previous_actual_state: #{previous_actual_state}, " \
              "current_actual_state: #{current_actual_state}, " \
              "workspace_exists: #{workspace_exists}"
          end
          expect(calculated_actual_state).to be(current_actual_state) if calculated_actual_state
        end
      end
    end

    # NOTE: The remaining examples below in this file existed before we added the RSpec parameterized
    #       section above with tests based on create_workspace_agent_info_hash. Some of them may be
    #       redundant now.

    context 'when the deployment is completed successfully' do
      context 'when new workspace has been created or existing workspace has been scaled up' do
        let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::RUNNING }
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                replicas: 1
              status:
                availableReplicas: 1
                conditions:
                - reason: MinimumReplicasAvailable
                  type: Available
                - reason: NewReplicaSetAvailable
                  type: Progressing
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end

      context 'when existing workspace has been scaled down' do
        let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::STOPPED }
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                replicas: 0
              status:
                conditions:
                - reason: MinimumReplicasAvailable
                  type: Available
                - reason: NewReplicaSetAvailable
                  type: Progressing
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end

      context 'when status does not contain required information' do
        let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::UNKNOWN }
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                test: 0
              status:
                conditions:
                - reason: MinimumReplicasAvailable
                  type: Available
                - reason: NewReplicaSetAvailable
                  type: Progressing
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end
    end

    context 'when the deployment is in progress' do
      context 'when new workspace has been created' do
        let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::STARTING }
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                replicas: 1
              status:
                conditions:
                - reason: NewReplicaSetCreated
                  type: Progressing
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end

      context 'when existing workspace has been updated' do
        let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::STARTING }
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                replicas: 1
              status:
                conditions:
                - reason: FoundNewReplicaSet
                  type: Progressing
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end

      context 'when existing workspace has been scaled up' do
        let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::STARTING }
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                replicas: 1
              status:
                conditions:
                - reason: ReplicaSetUpdated
                  type: Progressing
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end

      context 'when existing workspace has been scaled down' do
        let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::STOPPING }
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                replicas: 0
              status:
                conditions:
                - reason: ReplicaSetUpdated
                  type: Progressing
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end

      context 'when spec replicas is more than 1' do
        let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::UNKNOWN }
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                replicas: 2
              status:
                conditions:
                - reason: ReplicaSetUpdated
                  type: Progressing
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end

      context 'when status does not contain required information' do
        let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::UNKNOWN }
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                replicas: 1
              status:
                conditions:
                - reason: test
                  type: test
            WORKSPACE_STATUS_YAML
          ).to_h
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end
    end

    context 'when the deployment is failed' do
      context 'when new workspace has been created or existing workspace has been scaled up' do
        let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::FAILED }
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                replicas: 1
              status:
                conditions:
                - reason: MinimumReplicasUnavailable
                  type: Available
                - reason: ProgressDeadlineExceeded
                  type: Progressing
                unavailableReplicas: 1
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end

      context 'when existing scaled down workspace which was failing has been scaled up' do
        let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::FAILED }
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                replicas: 1
              status:
                conditions:
                - reason: MinimumReplicasUnavailable
                  type: Available
                - reason: NewReplicaSetAvailable
                  type: Progressing
                unavailableReplicas: 1
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          pending "This currently returns STARTING state. See related TODOs in the relevant code."
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end
    end

    context 'when the deployment status is unknown' do
      let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::UNKNOWN }

      context 'when spec is missing' do
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              test:
                replicas: 0
              status:
                conditions:
                - reason: ReplicaSetUpdated
                  type: Progressing
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end

      context 'when spec replicas is missing' do
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                test: 0
              status:
                conditions:
                - reason: ReplicaSetUpdated
                  type: Progressing
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end

      context 'when status is missing' do
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                replicas: 0
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end

      context 'when status conditions is missing' do
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                replicas: 0
              status:
                test:
                - reason: ReplicaSetUpdated
                  type: Progressing
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end

      context 'when status conditions reason is missing' do
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                replicas: 0
              status:
                conditions:
                - type: Progressing
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end

      context 'when status progressing and available conditions are unrecognized' do
        let(:latest_k8s_deployment_info) do
          yaml_safe_load_symbolized(
            <<~WORKSPACE_STATUS_YAML
              spec:
                replicas: 0
              status:
                conditions:
                - reason: unrecognized
                  type: Available
                - reason: unrecognized
                  type: Progressing
            WORKSPACE_STATUS_YAML
          )
        end

        it 'returns the expected actual state' do
          expect(actual_state_calculator.calculate_actual_state(latest_k8s_deployment_info: latest_k8s_deployment_info))
            .to be(expected_actual_state)
        end
      end
    end

    context 'when termination_progress is Terminating' do
      let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::TERMINATING }
      let(:termination_progress) do
        RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ActualStateCalculator::TERMINATING
      end

      it 'returns the expected actual state' do
        expect(
          actual_state_calculator.calculate_actual_state(
            latest_k8s_deployment_info: nil,
            termination_progress: termination_progress
          )
        ).to be(expected_actual_state)
      end
    end

    context 'when termination_progress is Terminated' do
      let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::TERMINATED }
      let(:termination_progress) do
        RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ActualStateCalculator::TERMINATED
      end

      it 'returns the expected actual state' do
        expect(
          actual_state_calculator.calculate_actual_state(
            latest_k8s_deployment_info: nil,
            termination_progress: termination_progress
          )
        ).to be(expected_actual_state)
      end
    end

    context 'when latest_error_details is present' do
      let(:latest_error_details) do
        {
          error_details: {
            error_type: RemoteDevelopment::WorkspaceOperations::Reconcile::ErrorType::APPLIER,
            error_details: "error encountered while applying k8s configs"
          }
        }
      end

      context "and termination_progress is missing" do
        let(:termination_progress) { nil }
        let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::ERROR }

        it 'returns the expected actual state' do
          expect(
            actual_state_calculator.calculate_actual_state(
              latest_k8s_deployment_info: nil,
              latest_error_details: latest_error_details
            )
          ).to be(expected_actual_state)
        end
      end

      context "and termination_progress is Terminated" do
        let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::TERMINATED }

        it 'returns the expected actual state' do
          expect(
            actual_state_calculator.calculate_actual_state(
              latest_k8s_deployment_info: nil,
              termination_progress:
                RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ActualStateCalculator::TERMINATED,
              latest_error_details: latest_error_details
            )
          ).to be(expected_actual_state)
        end
      end

      context "and termination_progress is Terminating" do
        let(:expected_actual_state) { RemoteDevelopment::WorkspaceOperations::States::ERROR }

        it 'returns the expected actual state' do
          expect(
            actual_state_calculator.calculate_actual_state(
              latest_k8s_deployment_info: nil,
              termination_progress:
                RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ActualStateCalculator::TERMINATING,
              latest_error_details: latest_error_details
            )
          ).to be(expected_actual_state)
        end
      end
    end
  end
end
