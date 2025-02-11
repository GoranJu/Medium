# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncProjectPoliciesWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let_it_be(:security_policy) do
    create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:deleted_security_policy) do
    create(:security_policy, :deleted, security_orchestration_policy_configuration: policy_configuration)
  end

  let(:project_id) { project.id }
  let(:policy_configuration_id) { policy_configuration.id }

  describe '#perform' do
    subject(:perform) { described_class.new.perform(project_id, policy_configuration_id) }

    context 'when project and policy configuration exist' do
      it 'calls SyncProjectService for each undeleted security policy' do
        expect(Security::SecurityOrchestrationPolicies::SyncProjectService).to receive(:new).with(
          project: project, security_policy: security_policy, policy_changes: {}
        ).and_call_original

        perform
      end
    end

    context 'when project does not exist' do
      let(:project_id) { non_existing_record_id }

      it 'does not call SyncProjectService' do
        expect(Security::SecurityOrchestrationPolicies::SyncProjectService).not_to receive(:new)

        perform
      end
    end

    context 'when policy configuration does not exist' do
      let(:policy_configuration_id) { non_existing_record_id }

      it 'does not call SyncProjectService' do
        expect(Security::SecurityOrchestrationPolicies::SyncProjectService).not_to receive(:new)

        perform
      end
    end

    context 'when there are no security policies' do
      let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }

      it 'does not call SyncProjectService' do
        expect(Security::SecurityOrchestrationPolicies::SyncProjectService).not_to receive(:new)

        perform
      end
    end
  end
end
