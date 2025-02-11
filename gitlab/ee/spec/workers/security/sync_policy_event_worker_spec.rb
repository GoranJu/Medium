# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncPolicyEventWorker, feature_category: :security_policy_management do
  let(:worker) { described_class.new }
  let(:event) { {} }

  describe '#handle_event' do
    subject(:handle_event) { worker.handle_event(event) }

    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    context 'when event is a protected branch event' do
      let_it_be(:project) { create(:project) }
      let_it_be(:protected_branch) { create(:protected_branch) }
      let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }

      let(:event) do
        Repositories::ProtectedBranchCreatedEvent.new(data: {
          protected_branch_id: protected_branch.id,
          parent_id: project.id,
          parent_type: 'project'
        })
      end

      before do
        allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
        end
      end

      context 'when security orchestration policies feature is not available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'does not sync rules' do
          expect(Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService).not_to receive(:new)
          expect(Security::SecurityOrchestrationPolicies::SyncPolicyEventService).not_to receive(:new)

          handle_event
        end
      end

      context 'with yaml model' do
        let(:sync_service) do
          instance_double(Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService)
        end

        before do
          stub_feature_flags(use_approval_policy_rules_for_approval_rules: false)
          allow(Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService)
            .to receive(:new)
            .with(policy_configuration)
            .and_return(sync_service)
        end

        it 'calls sync service with correct parameters' do
          expect(sync_service).to receive(:execute).with(project.id,
            { delay: described_class::SYNC_SERVICE_DELAY_INTERVAL })

          handle_event
        end
      end

      context 'with read model' do
        let(:security_policy) do
          create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
        end

        before do
          stub_feature_flags(use_approval_policy_rules_for_approval_rules: true)

          create(:security_policy_project_link, project: project, security_policy: security_policy)
        end

        it 'executes the sync service for each security policy' do
          expect(Security::SecurityOrchestrationPolicies::SyncPolicyEventService)
            .to receive(:new)
            .with(hash_including(project: project, security_policy: security_policy))
            .and_return(instance_double(Security::SecurityOrchestrationPolicies::SyncPolicyEventService, execute: true))

          handle_event
        end
      end
    end

    context 'when event is for a group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:policy_configuration) do
        create(:security_orchestration_policy_configuration, namespace: group, project: nil)
      end

      let(:event) do
        Repositories::ProtectedBranchCreatedEvent.new(data: {
          protected_branch_id: protected_branch.id,
          parent_id: group.id,
          parent_type: 'group'
        })
      end

      let_it_be(:project_1) { create(:project, group: group) }
      let_it_be(:project_2) { create(:project, group: group) }
      let_it_be(:project_3) { create(:project, group: group) }

      let_it_be(:protected_branch) { create(:protected_branch) }

      before do
        allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
        end
      end

      context 'with yaml model' do
        let(:sync_service) do
          instance_double(Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService)
        end

        before do
          stub_feature_flags(use_approval_policy_rules_for_approval_rules: false)
          allow(Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesProjectService)
            .to receive(:new)
            .with(policy_configuration)
            .and_return(sync_service)
        end

        it 'calls sync_rules_for_group for each configuration' do
          expect(sync_service).to receive(:execute).with(project_1.id, { delay: 0 })
          expect(sync_service).to receive(:execute).with(project_2.id, { delay: 0 })
          expect(sync_service).to receive(:execute).with(project_3.id, { delay: 0 })

          handle_event
        end
      end

      context 'with read model' do
        let(:security_policy) do
          create(:security_policy,
            security_orchestration_policy_configuration: policy_configuration,
            linked_projects: [project_1, project_2, project_3]
          )
        end

        before do
          stub_feature_flags(use_approval_policy_rules_for_approval_rules: true)
        end

        it 'executes the sync service for each security policy' do
          expect(Security::SecurityOrchestrationPolicies::SyncPolicyEventService)
            .to receive(:new)
            .with(hash_including(project: project_1, security_policy: security_policy))
            .and_return(instance_double(Security::SecurityOrchestrationPolicies::SyncPolicyEventService, execute: true))
          expect(Security::SecurityOrchestrationPolicies::SyncPolicyEventService)
            .to receive(:new)
            .with(hash_including(project: project_2, security_policy: security_policy))
            .and_return(instance_double(Security::SecurityOrchestrationPolicies::SyncPolicyEventService, execute: true))
          expect(Security::SecurityOrchestrationPolicies::SyncPolicyEventService)
            .to receive(:new)
            .with(hash_including(project: project_3, security_policy: security_policy))
            .and_return(instance_double(Security::SecurityOrchestrationPolicies::SyncPolicyEventService, execute: true))

          handle_event
        end
      end
    end

    context 'when event is not a protected branch event' do
      let(:event) { {} }

      it 'raises ArgumentError' do
        expect { handle_event }.to raise_error(ArgumentError, "Unknown event: Hash")
      end
    end
  end
end
