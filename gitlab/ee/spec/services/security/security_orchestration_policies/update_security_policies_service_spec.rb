# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::UpdateSecurityPoliciesService, feature_category: :security_policy_management do
  let(:service) { described_class.new(policies_changes: policies_changes) }

  let_it_be(:db_policy) do
    create(:security_policy, name: 'Policy', description: 'description')
  end

  let_it_be(:rule_content_1) do
    {
      type: 'scan_finding',
      branches: [],
      scanners: %w[container_scanning],
      vulnerabilities_allowed: 0,
      severity_levels: %w[critical],
      vulnerability_states: %w[detected]
    }
  end

  let_it_be(:rule_content_2) do
    {
      type: 'scan_finding',
      branches: [],
      scanners: %w[dependency_scanning],
      vulnerabilities_allowed: 0,
      severity_levels: %w[critical],
      vulnerability_states: %w[detected]
    }
  end

  let_it_be(:rule_content_3) do
    {
      type: 'license_finding',
      branches: [],
      match_on_inclusion_license: true,
      license_types: %w[BSD MIT],
      license_states: %w[newly_detected detected]
    }
  end

  let_it_be(:yaml_policy) do
    {
      name: 'Policy',
      description: 'description',
      rules: [rule_content_1, rule_content_2]
    }
  end

  let_it_be(:approval_policy_rule_1) do
    create(:approval_policy_rule, :scan_finding, rule_index: 1, security_policy: db_policy, content: rule_content_1)
  end

  let_it_be(:approval_policy_rule_2) do
    create(:approval_policy_rule, :scan_finding, rule_index: 2, security_policy: db_policy, content: rule_content_2)
  end

  let(:policies_changes) do
    [Security::SecurityOrchestrationPolicies::PolicyComparer.new(
      db_policy: db_policy,
      yaml_policy: yaml_policy,
      policy_index: 0
    )]
  end

  describe '#execute' do
    context 'when there are no policy changes' do
      it 'does not update any policies' do
        expect { service.execute }.to not_change { db_policy.name }
          .and not_change { db_policy.description }
          .and not_change { db_policy.rules.count }.from(2)
      end
    end

    context 'when there are policy changes and created rules' do
      let(:yaml_policy) do
        {
          name: 'Updated Policy',
          description: 'Updated description',
          rules: [rule_content_1, rule_content_2, rule_content_3]
        }
      end

      it 'updates policy attributes and rules' do
        expect { service.execute }.to change { db_policy.name }.to('Updated Policy')
          .and change { db_policy.description }.to('Updated description')
          .and change { db_policy.rules.count }.from(2).to(3)
      end
    end

    context 'when there are deleted rules' do
      let(:yaml_policy) do
        {
          name: 'Updated Policy',
          description: 'Updated description',
          rules: [rule_content_2]
        }
      end

      it 'sets the deleted rules to be deleted' do
        expect { service.execute }.to change { Security::ApprovalPolicyRule.last.rule_index }.from(2).to(-2)
          .and change {
                 Security::ApprovalPolicyRule.first.typed_content.deep_symbolize_keys
               }.from(rule_content_1).to(rule_content_2)
      end
    end

    context 'when there are updated rules' do
      let(:yaml_policy) do
        {
          name: 'Updated Policy',
          description: 'Updated description',
          rules: [rule_content_1, rule_content_3]
        }
      end

      it 'updates the existing rules' do
        expect { service.execute }.to change {
                                        Security::ApprovalPolicyRule.last.typed_content.deep_symbolize_keys
                                      }.to(rule_content_3)
      end
    end

    context 'when the content of pipeline execution policy gets updated' do
      let_it_be(:old_config_project) { create(:project, :empty_repo) }
      let_it_be(:new_config_project) { create(:project, :empty_repo) }
      let_it_be(:db_policy) do
        create(:security_policy, :pipeline_execution_policy, name: 'Policy',
          content: {
            pipeline_config_strategy: 'inject_ci',
            content: { include: [{ project: old_config_project.full_path, file: 'file.yml' }] }
          })
      end

      let(:yaml_policy) do
        {
          name: 'Updated Policy',
          content: { include: [{ project: new_config_project.full_path, file: 'file.yml' }] }
        }
      end

      before do
        db_policy.update_pipeline_execution_policy_config_link!
      end

      context 'when project in the content gets updated' do
        it 'updates the policy config links' do
          expect { service.execute }.to change { db_policy.reload.security_pipeline_execution_policy_config_link }
          expect(db_policy.security_pipeline_execution_policy_config_link.project).to eq(new_config_project)
        end
      end

      context 'when file in the content gets updated' do
        let(:yaml_policy) do
          {
            name: 'Updated Policy',
            content: { include: [{ project: old_config_project.full_path, file: 'new_file.yml' }] }
          }
        end

        it 'does not update the policy config links' do
          expect { service.execute }.not_to change { db_policy.reload.security_pipeline_execution_policy_config_link }
        end
      end

      context 'when ref in the content gets updated' do
        let(:yaml_policy) do
          {
            name: 'Updated Policy',
            content: { include: [{ project: old_config_project.full_path, file: 'file.yml', ref: 'develop' }] }
          }
        end

        it 'does not update the policy config links' do
          expect { service.execute }.not_to change { db_policy.reload.security_pipeline_execution_policy_config_link }
        end
      end
    end
  end
end
