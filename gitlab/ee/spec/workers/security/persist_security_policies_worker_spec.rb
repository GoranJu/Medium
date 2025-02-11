# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PersistSecurityPoliciesWorker, '#perform', feature_category: :security_policy_management do
  include_context 'with scan result policy' do
    let(:policy_configuration) { create(:security_orchestration_policy_configuration) }

    let(:policy_yaml) do
      build(
        :orchestration_policy_yaml,
        scan_execution_policy: scan_execution_policies,
        scan_result_policy: scan_result_policies,
        pipeline_execution_policy: pipeline_execution_policies,
        vulnerability_management_policy: vulnerability_management_policies,
        pipeline_execution_schedule_policy: pipeline_execution_schedule_policies
      )
    end

    let(:scan_result_policies) { build_list(:scan_result_policy, 2) + [build(:scan_result_policy, active: false)] }
    let(:scan_execution_policies) do
      build_list(:scan_execution_policy, 2) + [build(:scan_execution_policy, active: false)]
    end

    let(:pipeline_execution_policies) do
      build_list(:pipeline_execution_policy, 2) + [build(:pipeline_execution_policy, active: false)]
    end

    let(:pipeline_execution_schedule_policies) do
      build_list(:pipeline_execution_schedule_policy, 1) + [build(:pipeline_execution_schedule_policy, active: false)]
    end

    let(:vulnerability_management_policies) do
      build_list(:vulnerability_management_policy, 2) + [build(:vulnerability_management_policy, active: false)]
    end

    it_behaves_like 'an idempotent worker' do
      subject(:perform) { perform_multiple(policy_configuration.id) }

      context 'when policy is empty' do
        let(:scan_result_policies) { [] }
        let(:scan_execution_policies) { [] }
        let(:pipeline_execution_policies) { [] }
        let(:vulnerability_management_policies) { [] }
        let(:pipeline_execution_schedule_policies) { [] }

        it 'does not persist policies' do
          expect { perform }.not_to change { policy_configuration.security_policies.reload.count }
        end

        context 'when policy already exists in database' do
          before do
            create(:security_policy, security_orchestration_policy_configuration: policy_configuration)
          end

          it 'deletes the policy' do
            expect { perform }.to change { Security::Policy.count }.from(1).to(0)
          end
        end
      end

      describe 'cache eviction' do
        let(:config) { spy }

        before do
          allow(Security::OrchestrationPolicyConfiguration)
            .to receive(:find_by_id).with(policy_configuration.id).and_return(config)

          allow(Gitlab::AppJsonLogger).to receive(:debug)
        end

        it 'evicts policy cache' do
          perform

          expect(config).to have_received(:invalidate_policy_yaml_cache).at_least(:once)
        end
      end

      it 'persists approval policies' do
        perform

        expect(policy_configuration.security_policies.type_approval_policy.count).to be(3)
      end

      it 'persists scan execution policies' do
        perform

        expect(policy_configuration.security_policies.type_scan_execution_policy.count).to be(3)
      end

      it 'persists pipeline execution policies' do
        perform

        expect(policy_configuration.security_policies.type_pipeline_execution_policy.count).to be(3)
      end

      it 'persists vulnerability management policies' do
        perform

        expect(policy_configuration.security_policies.type_vulnerability_management_policy.count).to be(3)
      end

      it 'persists pipeline execution schedule policies' do
        perform

        expect(policy_configuration.security_policies.type_pipeline_execution_schedule_policy.count).to be(2)
      end

      it 'calls SyncScanResultPoliciesService' do
        expect_next_instance_of(
          Security::SecurityOrchestrationPolicies::SyncScanResultPoliciesService, policy_configuration
        ) do |service|
          expect(service).to receive(:execute).with(no_args)
        end.exactly(IdempotentWorkerHelper::WORKER_EXEC_TIMES)

        perform
      end
    end
  end
end
