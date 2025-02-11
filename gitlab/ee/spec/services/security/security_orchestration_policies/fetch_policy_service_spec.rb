# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::FetchPolicyService, feature_category: :security_policy_management do
  describe '#execute' do
    let(:project) { create(:project) }
    let(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let(:policy) { build(:scan_execution_policy) }
    let(:policy_blob) { build(:orchestration_policy_yaml, scan_execution_policy: [policy]) }
    let(:type) { :scan_execution_policy }
    let(:name) { policy[:name] }
    let(:service) { described_class.new(policy_configuration: policy_configuration, name: name, type: type) }

    subject(:response) { service.execute }

    before do
      allow_next_instance_of(Repository) do |repository|
        allow(repository).to receive(:blob_data_at).and_return(policy_blob)
      end
    end

    context 'when retrieving an existing policy by name' do
      it 'returns policy' do
        expect(response[:status]).to eq(:success)
        expect(response[:policy]).to eq(policy)
      end
    end

    context 'when retrieving an non-existing policy by name' do
      let(:name) { 'Invalid name' }

      it 'returns nil' do
        expect(response[:status]).to eq(:success)
        expect(response[:policy]).to eq(nil)
      end
    end

    describe 'multiple scan result policy types' do
      let(:scan_result_policy) { build(:scan_result_policy) }
      let(:approval_policy) { build(:approval_policy) }
      let(:policy_blob) do
        build(:orchestration_policy_yaml,
          scan_execution_policy: [build(:scan_execution_policy)],
          scan_result_policy: [scan_result_policy],
          approval_policy: [approval_policy])
      end

      shared_examples 'returns policy matching the name regardless of type' do
        context 'when name matches scan_result_policy' do
          let(:name) { scan_result_policy[:name] }

          it 'returns scan_result_policy matching the name' do
            expect(response[:status]).to eq(:success)
            expect(response[:policy]).to eq(scan_result_policy)
          end
        end

        context 'when name matches approval_policy' do
          let(:name) { approval_policy[:name] }

          it 'returns approval_policy matching the name' do
            expect(response[:status]).to eq(:success)
            expect(response[:policy]).to eq(approval_policy)
          end
        end
      end

      context 'when type is approval_policy' do
        let(:type) { :approval_policy }

        it_behaves_like 'returns policy matching the name regardless of type'
      end

      context 'when type is scan_result_policy' do
        let(:type) { :scan_result_policy }

        it_behaves_like 'returns policy matching the name regardless of type'
      end
    end
  end
end
