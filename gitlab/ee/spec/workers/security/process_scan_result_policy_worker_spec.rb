# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProcessScanResultPolicyWorker, feature_category: :security_policy_management do
  let_it_be(:configuration, refind: true) { create(:security_orchestration_policy_configuration, configured_at: nil) }

  let(:policies) do
    {
      scan_execution_policy: [],
      scan_result_policy:
      [
        {
          name: 'CS critical policy',
          description: 'This policy with CS for critical policy',
          enabled: true,
          rules: [
            { type: 'scan_finding', branches: %w[production], vulnerabilities_allowed: 0,
              severity_levels: %w[critical], scanners: %w[container_scanning],
              vulnerability_states: %w[newly_detected] }
          ],
          actions: [
            { type: 'require_approval', approvals_required: 1, user_approvers: %w[admin] }
          ]
        },
        {
          name: 'Disabled policy',
          description: 'This policy with CS for critical policy',
          enabled: false,
          rules: [
            { type: 'scan_finding', branches: %w[production], vulnerabilities_allowed: 0,
              severity_levels: %w[critical], scanners: %w[container_scanning],
              vulnerability_states: %w[newly_detected] }
          ],
          actions: [
            { type: 'require_approval', approvals_required: 1, user_approvers: %w[admin] }
          ]
        }
      ]
    }
  end

  let(:active_scan_result_policies) do
    policies[:scan_result_policy].select { |policy| policy[:enabled] }
                                 .map { |policy| policy.merge({ type: 'scan_result_policy' }) }
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [configuration.project.id, configuration.id] }
  end

  before do
    allow_next_instance_of(Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policies.to_yaml)
      allow(repository).to receive(:last_commit_for_path)
    end

    stub_feature_flags(use_approval_policy_rules_for_approval_rules: false)
  end

  describe '#perform' do
    subject(:worker) { described_class.new }

    describe 'metrics' do
      specify do
        described_class::HISTOGRAMS.each_value do |histogram|
          hist = Security::SecurityOrchestrationPolicies::ObserveHistogramsService.histogram(histogram)

          expect(hist)
            .to receive(:observe).with({}, kind_of(Float)).and_call_original
        end

        worker.perform(configuration.project_id, configuration.id)
      end
    end

    describe 'logging' do
      it 'logs duration, project ID and configuration ID for each event' do
        allow(Gitlab::AppJsonLogger).to receive(:debug)

        described_class::HISTOGRAMS.each_key do |event|
          expect(Gitlab::AppJsonLogger).to receive(:debug).with(
            hash_including(
              "class" => described_class.name,
              "duration" => kind_of(Float),
              "event" => event,
              "project_id" => configuration.project_id,
              "configuration_id" => configuration.id))
        end

        worker.perform(configuration.project_id, configuration.id)
      end
    end

    it_behaves_like 'when no policy is applicable due to the policy scope' do
      it 'does not call ProcessScanResultPolicyService to create approval rules' do
        expect(Security::SecurityOrchestrationPolicies::ProcessScanResultPolicyService).not_to receive(:new)

        worker.perform(configuration.project_id, configuration.id)
      end
    end

    it_behaves_like 'when policy is applicable based on the policy scope configuration' do
      it 'calls two services to general merge request approval rules from the policy YAML' do
        active_scan_result_policies.each_with_index do |policy, policy_index|
          expect_next_instance_of(
            Security::SecurityOrchestrationPolicies::ProcessScanResultPolicyService,
            project: configuration.project,
            policy_configuration: configuration,
            policy: policy,
            policy_index: policy_index,
            real_policy_index: 0
          ) do |service|
            expect(service).to receive(:execute)
          end
          expect_next_instance_of(
            Security::SecurityOrchestrationPolicies::SyncOpenedMergeRequestsService,
            project: configuration.project,
            policy_configuration: configuration
          ) do |service|
            expect(service).to receive(:execute)
          end
        end

        worker.perform(configuration.project_id, configuration.id)
      end
    end

    context 'with multiple policies' do
      let(:policies) do
        {
          scan_execution_policy: [],
          scan_result_policy:
          [
            {
              name: 'CS critical policy',
              description: 'This policy with CS for critical policy',
              enabled: true,
              rules: [
                { type: 'scan_finding', branches: %w[production], vulnerabilities_allowed: 0,
                  severity_levels: %w[critical], scanners: %w[container_scanning],
                  vulnerability_states: %w[newly_detected] }
              ],
              actions: [
                { type: 'require_approval', approvals_required: 1, user_approvers: %w[admin] }
              ]
            },
            {
              name: 'Disabled policy',
              description: 'This policy with CS for critical policy',
              enabled: false,
              rules: [
                { type: 'scan_finding', branches: %w[production], vulnerabilities_allowed: 0,
                  severity_levels: %w[critical], scanners: %w[container_scanning],
                  vulnerability_states: %w[newly_detected] }
              ],
              actions: [
                { type: 'require_approval', approvals_required: 1, user_approvers: %w[admin] }
              ]
            },
            {
              name: 'DS critical policy',
              description: 'This policy with DS for critical policy',
              enabled: true,
              rules: [
                { type: 'scan_finding', branches: %w[production], vulnerabilities_allowed: 0,
                  severity_levels: %w[critical], scanners: %w[dependency_scanning],
                  vulnerability_states: %w[newly_detected] }
              ],
              actions: [
                { type: 'require_approval', approvals_required: 1, user_approvers: %w[admin] }
              ]
            }
          ]
        }
      end

      it_behaves_like 'when policy is applicable based on the policy scope configuration' do
        it 'calls service with correct policy_index and real_policy_index' do
          expect_next_instance_of(
            Security::SecurityOrchestrationPolicies::ProcessScanResultPolicyService,
            project: configuration.project,
            policy_configuration: configuration,
            policy: active_scan_result_policies[0],
            policy_index: 0,
            real_policy_index: 0
          ) do |service|
            expect(service).to receive(:execute)
          end
          expect_next_instance_of(
            Security::SecurityOrchestrationPolicies::ProcessScanResultPolicyService,
            project: configuration.project,
            policy_configuration: configuration,
            policy: active_scan_result_policies[1],
            policy_index: 1,
            real_policy_index: 2
          ) do |service|
            expect(service).to receive(:execute)
          end

          worker.perform(configuration.project_id, configuration.id)
        end
      end
    end

    context 'without transaction' do
      it 'does not wrap the execution within transaction' do
        expect(Security::OrchestrationPolicyConfiguration).not_to receive(:transaction).and_yield

        worker.perform(configuration.project_id, configuration.id)
      end
    end

    shared_context 'with scan_result_policy_reads' do
      let(:scan_result_policy_read) do
        create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration, project: project)
      end

      let!(:software_license_without_scan_result_policy) do
        create(:software_license_policy, project: project)
      end

      let!(:software_license_with_scan_result_policy) do
        create(:software_license_policy, project: project,
          scan_result_policy_read: scan_result_policy_read)
      end

      subject(:perform) { worker.perform(project.id, configuration.id) }

      it 'deletes software_license_policies associated to the project' do
        worker.perform(project.id, configuration.id)

        software_license_policies = SoftwareLicensePolicy.where(project_id: project.id)
        expect(software_license_policies).to match_array([software_license_without_scan_result_policy])
      end

      context 'with existing scan_result_policy_reads' do
        def scan_result_policy_read_exists?
          Security::ScanResultPolicyRead.exists?(scan_result_policy_read.id)
        end

        def scan_result_policy_violation_exists?(violation)
          Security::ScanResultPolicyViolation.exists?(violation.id)
        end

        context 'with matching project_id' do
          it 're-creates scan_result_policy_reads' do
            expect { perform }.to change { scan_result_policy_read_exists? }.to(false)
          end

          context 'with scan_result_policy_violations' do
            let!(:scan_result_policy_violation) do
              create(:scan_result_policy_violation,
                project: project,
                merge_request: create(:merge_request, source_project: project, target_project: project),
                scan_result_policy_read: scan_result_policy_read)
            end

            it 'deletes violations' do
              expect { perform }.to change {
                                      scan_result_policy_violation_exists?(scan_result_policy_violation)
                                    }.to(false)
            end
          end

          context 'with other scan_result_policy_violations' do
            let_it_be(:other_project) { create(:project) }

            let!(:other_scan_result_policy_violation) do
              create(:scan_result_policy_violation,
                project: other_project,
                merge_request: create(:merge_request, source_project: other_project,
                  target_project: other_project),
                scan_result_policy_read: create(:scan_result_policy_read, project: other_project))
            end

            it "does not delete other projects' violations" do
              expect { perform }.not_to change {
                                          scan_result_policy_violation_exists?(other_scan_result_policy_violation)
                                        }
            end
          end
        end
      end
    end

    context 'when policies are inactive' do
      let_it_be(:project) { configuration.project }

      let_it_be(:scan_result_policy_read) do
        create(:scan_result_policy_read, project: project, security_orchestration_policy_configuration: configuration)
      end

      let_it_be(:approval_rule) do
        create(:approval_project_rule, :scan_finding,
          project: project, security_orchestration_policy_configuration_id: configuration.id,
          scan_result_policy_read: scan_result_policy_read
        )
      end

      let_it_be(:mr_approval_rule) do
        create(:report_approver_rule, :scan_finding,
          merge_request: create(:merge_request, source_project: project),
          security_orchestration_policy_configuration_id: configuration.id,
          scan_result_policy_read: scan_result_policy_read
        )
      end

      let(:policies) do
        {
          scan_execution_policy: [],
          scan_result_policy:
          [
            {
              name: 'CS critical policy',
              description: 'This policy with CS for critical policy',
              enabled: false,
              rules: [
                { type: 'scan_finding', branches: %w[production], vulnerabilities_allowed: 0,
                  severity_levels: %w[critical], scanners: %w[container_scanning],
                  vulnerability_states: %w[newly_detected] }
              ],
              actions: [
                { type: 'require_approval', approvals_required: 1, user_approvers: %w[admin] }
              ]
            }
          ]
        }
      end

      it 'returns prior to triggering service' do
        not_call_process_scan_result_policy_service

        worker.perform(project.id, configuration.id)

        expect { mr_approval_rule.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { approval_rule.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when policy is linked to a project level' do
      let_it_be(:project) { configuration.project }

      include_context 'with scan_result_policy_reads'
    end

    context 'when policy is linked to a group level' do
      let_it_be(:project) { create(:project) }
      let_it_be(:configuration) do
        create(:security_orchestration_policy_configuration,
          namespace: project.namespace,
          project: nil,
          configured_at: nil
        )
      end

      include_context 'with scan_result_policy_reads'
    end

    def not_call_process_scan_result_policy_service
      expect(Security::SecurityOrchestrationPolicies::ProcessScanResultPolicyService).not_to receive(:execute)
    end

    context 'with non existing project' do
      it 'returns prior to triggering service' do
        not_call_process_scan_result_policy_service

        worker.perform('invalid_id', configuration.id)
      end
    end

    context 'with non existing configuration' do
      it 'returns prior to triggering service' do
        not_call_process_scan_result_policy_service

        worker.perform(configuration.project_id, 'invalid_id')
      end
    end

    context 'when no scan result policies are configured' do
      before do
        allow_next_instance_of(Repository) do |repository|
          allow(repository).to receive(:blob_data_at).and_return([].to_yaml)
        end
      end

      it 'returns prior to triggering service' do
        not_call_process_scan_result_policy_service

        worker.perform(configuration.project_id, 'invalid_id')
      end
    end

    context 'with approval rules for merged MRs' do
      let_it_be(:project) { configuration.project }
      let_it_be_with_reload(:merge_request_to_be_merged) do
        create(:merge_request,
          target_project: project,
          source_project: project,
          source_branch: 'feature-1')
      end

      let_it_be(:scan_result_policy_read) do
        create(:scan_result_policy_read, project: project, security_orchestration_policy_configuration: configuration)
      end

      let_it_be_with_reload(:approval_merge_request_rule) do
        create(:report_approver_rule,
          :scan_finding,
          merge_request: merge_request_to_be_merged,
          security_orchestration_policy_configuration_id: configuration.id,
          scan_result_policy_read: scan_result_policy_read)
      end

      before do
        merge_request_to_be_merged.mark_as_merged!
      end

      it 'does not delete approval merge request rules for merged MRs' do
        worker.perform(configuration.project_id, configuration.id)

        expect(ApprovalMergeRequestRule.find(approval_merge_request_rule.id)).not_to be_nil
      end

      it 'nullifies scan_result_policy_id in approval merge request rules for merged MRs' do
        worker.perform(configuration.project_id, configuration.id)

        expect(ApprovalMergeRequestRule.find(approval_merge_request_rule.id).scan_result_policy_id).to be_nil
      end
    end

    context 'when use_approval_policy_rules_for_approval_rules is enabled' do
      before do
        stub_feature_flags(use_approval_policy_rules_for_approval_rules: true)
      end

      it 'does not call service' do
        expect(Security::SecurityOrchestrationPolicies::ProcessScanResultPolicyService).not_to receive(:execute)
        expect(Security::SecurityOrchestrationPolicies::SyncOpenedMergeRequestsService).not_to receive(:execute)

        worker.perform(configuration.project_id, configuration.id)
      end
    end
  end
end
