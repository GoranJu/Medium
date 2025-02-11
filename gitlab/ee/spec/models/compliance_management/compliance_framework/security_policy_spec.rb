# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::SecurityPolicy, feature_category: :security_policy_management do
  describe 'Associations' do
    subject { create(:compliance_framework_security_policy) }

    it 'belongs to compliance framework and security_orchestration_policy_configuration' do
      expect(subject).to belong_to(:framework)
      expect(subject).to belong_to(:policy_configuration)
    end

    it { is_expected.to have_many(:security_policy_requirements) }
    it { is_expected.to have_many(:compliance_requirements).through(:security_policy_requirements) }
  end

  describe 'validations' do
    subject { create(:compliance_framework_security_policy) }

    it { is_expected.to validate_uniqueness_of(:framework).scoped_to([:policy_configuration_id, :policy_index]) }
  end

  describe '.for_framework' do
    let_it_be(:framework_1) { create(:compliance_framework) }
    let_it_be(:framework_2) { create(:compliance_framework) }
    let_it_be(:policy_1) { create(:compliance_framework_security_policy, framework: framework_1) }
    let_it_be(:policy_2) { create(:compliance_framework_security_policy, framework: framework_2) }

    subject { described_class.for_framework(framework_1) }

    it { is_expected.to eq([policy_1]) }
  end

  describe '.for_policy_configuration' do
    let_it_be(:policy_configuration_1) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy_configuration_2) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy_1) { create(:compliance_framework_security_policy, policy_configuration: policy_configuration_1) }
    let_it_be(:policy_2) { create(:compliance_framework_security_policy, policy_configuration: policy_configuration_2) }

    subject { described_class.for_policy_configuration(policy_configuration_1) }

    it { is_expected.to eq([policy_1]) }
  end

  describe '.relink' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:other_policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:framework) { create(:compliance_framework) }
    let_it_be(:other_framework) { create(:compliance_framework) }

    let(:attrs) do
      [
        { framework_id: framework.id, policy_configuration_id: policy_configuration.id, policy_index: 1 }
      ]
    end

    subject(:relink) { described_class.relink(policy_configuration, attrs) }

    context 'when there are no already existing policies' do
      it 'creates new record' do
        relink

        expect(described_class.count).to eq(1)
        expect(described_class.first).to have_attributes(
          framework: framework,
          policy_configuration: policy_configuration,
          policy_index: 1
        )
      end
    end

    context 'when there are already existing policies' do
      let_it_be(:policy) do
        create(:compliance_framework_security_policy,
          framework: framework,
          policy_configuration: policy_configuration
        )
      end

      let_it_be(:other_policy) do
        create(:compliance_framework_security_policy,
          framework: other_framework,
          policy_configuration: other_policy_configuration
        )
      end

      it 'deletes and recreates policy with updated policy_index' do
        relink

        expect { policy.reload }.to raise_exception(ActiveRecord::RecordNotFound)
        expect(policy_configuration.compliance_framework_security_policies.first.policy_index).to eq(1)
      end

      it 'does not update count' do
        expect { relink }.not_to change { described_class.count }
      end

      it 'does not update other policies' do
        expect { relink }.not_to change { other_policy.reload.policy_index }
      end
    end
  end
end
