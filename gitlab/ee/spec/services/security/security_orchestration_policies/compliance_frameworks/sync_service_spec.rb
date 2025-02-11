# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ComplianceFrameworks::SyncService, '#execute', feature_category: :security_policy_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, namespace: namespace, project: nil)
  end

  let_it_be(:framework1) { create(:compliance_framework, namespace: namespace, name: 'GDPR') }
  let_it_be(:framework2) { create(:compliance_framework, namespace: namespace, name: 'SOX') }

  let(:framework_ids_and_idx) { [] }
  let(:all_records) { ComplianceManagement::ComplianceFramework::SecurityPolicy.all }

  subject(:execute) { described_class.new(policy_configuration).execute }

  before do
    allow(policy_configuration).to receive(:compliance_framework_ids_with_policy_index)
      .and_return(framework_ids_and_idx)
  end

  shared_examples 'does not create ComplianceFramework::SecurityPolicy' do
    it { expect { execute }.not_to change { ComplianceManagement::ComplianceFramework::SecurityPolicy.count } }
  end

  context 'when no compliance frameworks are linked' do
    it_behaves_like 'does not create ComplianceFramework::SecurityPolicy'
  end

  context 'when policy configuration is scoped to a project' do
    let_it_be(:project) { create(:project, :repository, namespace: namespace) }
    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    let(:framework_ids_and_idx) do
      [
        { framework_ids: [framework1.id, framework2.id], policy_index: 0 }
      ]
    end

    it 'creates ComplianceFramework::SecurityPolicy' do
      execute

      expect(all_records.count).to eq(2)
      expect(all_records.map(&:policy_index)).to contain_exactly(0, 0)
      expect(all_records.map(&:policy_configuration_id)).to contain_exactly(policy_configuration.id,
        policy_configuration.id)
      expect(all_records.map(&:framework_id)).to contain_exactly(framework1.id, framework2.id)
    end
  end

  context 'when inaccessible compliance framework is linked to policy' do
    let_it_be(:inaccessible_framework) { create(:compliance_framework) }
    let(:framework_ids_and_idx) do
      [
        { framework_ids: [inaccessible_framework.id], policy_index: 0 }
      ]
    end

    it_behaves_like 'does not create ComplianceFramework::SecurityPolicy'

    it 'logs details' do
      expect(::Gitlab::AppJsonLogger).to receive(:info).once.with(
        message: 'inaccessible compliance_framework_ids found in policy',
        configuration_id: policy_configuration.id,
        configuration_source_id: policy_configuration.source.id,
        root_namespace_id: namespace.id,
        policy_framework_ids: [inaccessible_framework.id],
        inaccessible_framework_ids_count: 1
      ).and_call_original

      execute
    end
  end

  context 'when non existing compliance framework is linked to policy' do
    let(:framework_ids_and_idx) do
      [
        { framework_ids: [non_existing_record_id], policy_index: 0 }
      ]
    end

    it_behaves_like 'does not create ComplianceFramework::SecurityPolicy'

    it 'logs details' do
      expect(::Gitlab::AppJsonLogger).to receive(:info).once.with(
        message: 'inaccessible compliance_framework_ids found in policy',
        configuration_id: policy_configuration.id,
        configuration_source_id: policy_configuration.source.id,
        root_namespace_id: namespace.id,
        policy_framework_ids: [non_existing_record_id],
        inaccessible_framework_ids_count: 1
      ).and_call_original

      execute
    end
  end

  context 'when multiple compliance frameworks are linked to policy' do
    let(:framework_ids_and_idx) do
      [
        { framework_ids: [framework1.id, framework2.id], policy_index: 0 }
      ]
    end

    it 'creates ComplianceFramework::SecurityPolicy' do
      execute

      expect(all_records.count).to eq(2)
      expect(all_records.map(&:policy_index)).to contain_exactly(0, 0)
      expect(all_records.map(&:policy_configuration_id)).to contain_exactly(policy_configuration.id,
        policy_configuration.id)
      expect(all_records.map(&:framework_id)).to contain_exactly(framework1.id, framework2.id)
    end
  end

  context 'when multiple compliance frameworks are linked to different policies' do
    let(:framework_ids_and_idx) do
      [
        { framework_ids: [framework1.id], policy_index: 0 },
        { framework_ids: [framework2.id], policy_index: 1 }
      ]
    end

    it 'creates ComplianceFramework::SecurityPolicy' do
      execute

      expect(all_records.count).to eq(2)
      expect(all_records.map(&:policy_index)).to contain_exactly(0, 1)
      expect(all_records.map(&:policy_configuration_id)).to contain_exactly(policy_configuration.id,
        policy_configuration.id)
      expect(all_records.map(&:framework_id)).to contain_exactly(framework1.id, framework2.id)
    end
  end
end
