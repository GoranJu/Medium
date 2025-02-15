# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::SecurityOrchestrationHelper, feature_category: :security_policy_management do
  let_it_be_with_reload(:project) { create(:project, group: create(:group)) }
  let_it_be_with_reload(:namespace) { create(:group, :public) }
  let_it_be(:timezones) { [{ identifier: "Europe/Paris" }] }

  describe '#can_update_security_orchestration_policy_project?' do
    let(:owner) { project.first_owner }

    before do
      allow(helper).to receive(:current_user) { owner }
    end

    it 'returns false when user cannot update security orchestration policy project' do
      allow(helper).to receive(:can?).with(owner, :update_security_orchestration_policy_project, project) { false }
      expect(helper.can_update_security_orchestration_policy_project?(project)).to eq false
    end

    it 'returns true when user can update security orchestration policy project' do
      allow(helper).to receive(:can?).with(owner, :update_security_orchestration_policy_project, project) { true }
      expect(helper.can_update_security_orchestration_policy_project?(project)).to eq true
    end
  end

  describe '#assigned_policy_project' do
    context 'for project' do
      subject { helper.assigned_policy_project(project) }

      context 'when a project does have a security policy project' do
        let_it_be(:policy_management_project) { create(:project) }

        let_it_be(:security_orchestration_policy_configuration) do
          create(
            :security_orchestration_policy_configuration,
            security_policy_management_project: policy_management_project, project: project
          )
        end

        it 'include information about policy management project' do
          is_expected.to include(
            id: policy_management_project.to_global_id.to_s,
            name: policy_management_project.name,
            full_path: policy_management_project.full_path,
            branch: policy_management_project.default_branch_or_main
          )
        end
      end

      context 'when a project does not have a security policy project' do
        subject { helper.assigned_policy_project(project) }

        it { is_expected.to be_nil }
      end
    end

    context 'for namespace' do
      subject { helper.assigned_policy_project(project) }

      context 'when a namespace does have a security policy project' do
        let_it_be(:policy_management_project) { create(:project) }
        let_it_be(:security_orchestration_policy_configuration) do
          create(
            :security_orchestration_policy_configuration, :namespace,
            security_policy_management_project: policy_management_project, namespace: namespace
          )
        end

        subject { helper.assigned_policy_project(namespace) }

        it 'include information about policy management project' do
          is_expected.to include({
            id: policy_management_project.to_global_id.to_s,
            name: policy_management_project.name,
            full_path: policy_management_project.full_path,
            branch: policy_management_project.default_branch_or_main
          })
        end
      end

      context 'when a namespace does not have a security policy project' do
        it { is_expected.to be_nil }
      end
    end
  end

  describe '#breadcrumb_by_type' do
    let_it_be(:policy_type) { 'approval_policy' }

    subject { helper.breadcrumb_by_type(policy_type) }

    context 'when merge request approval policy' do
      it 'returns correct breadcrumb type' do
        is_expected.to eq('New merge request approval policy')
      end
    end

    context 'when scan execution policy' do
      let_it_be(:policy_type) { 'scan_execution_policy' }

      it 'returns correct breadcrumb type' do
        is_expected.to eq('New scan execution policy')
      end
    end

    context 'when pipeline execution policy' do
      let_it_be(:policy_type) { 'pipeline_execution_policy' }

      it 'returns correct breadcrumb type' do
        is_expected.to eq('New pipeline execution policy')
      end
    end

    context 'when policy type does not exist' do
      let_it_be(:policy_type) { 'wrong type' }

      it 'returns correct breadcrumb type' do
        is_expected.to eq('New policy')
      end
    end
  end

  describe '#orchestration_policy_data' do
    shared_examples_for 'loads software_licenses names' do
      context 'for software_licenses' do
        context 'when static_licenses feature flag is disabled' do
          before do
            stub_feature_flags(static_licenses: false)
          end

          it 'gets the license names from SoftwareLicense' do
            expect(SoftwareLicense).to receive(:all_license_names)

            orchestration_policy_data
          end
        end

        context 'when static_licenses feature flag is enabled' do
          it 'gets the license names from ::Gitlab::SPDX::Catalogue' do
            expect(::Gitlab::SPDX::Catalogue).to receive(:latest_active_license_names)

            orchestration_policy_data
          end
        end
      end
    end

    context 'for project' do
      let(:approvers) { { single_approvers: %w[approver1 approver2] } }
      let(:owner) { project.first_owner }
      let(:policy) { nil }
      let(:policy_type) { 'scan_execution_policy' }
      let(:base_data) do
        {
          assigned_policy_project: nil.to_json,
          disable_scan_policy_update: 'false',
          create_agent_help_path: kind_of(String),
          namespace_id: project.id,
          namespace_path: kind_of(String),
          policy_editor_empty_state_svg_path: kind_of(String),
          policies_path: kind_of(String),
          policy: policy&.to_json,
          policy_type: policy_type,
          role_approver_types: %w[developer maintainer owner],
          scan_policy_documentation_path: kind_of(String),
          action_approvers: approvers&.to_json,
          software_licenses: kind_of(Array),
          global_group_approvers_enabled:
            Gitlab::CurrentSettings.security_policy_global_group_approvers_enabled.to_json,
          root_namespace_path: project.root_ancestor.full_path,
          timezones: timezones.to_json,
          max_active_scan_execution_policies_reached: 'false',
          max_active_pipeline_execution_policies_reached: 'false',
          max_active_scan_result_policies_reached: 'false',
          max_scan_result_policies_allowed: Gitlab::CurrentSettings.security_approval_policies_limit,
          max_scan_execution_policies_allowed: 5,
          max_pipeline_execution_policies_allowed: 5,
          max_ci_component_publishing_policies_allowed: 5,
          max_ci_component_publishing_policies_reached: 'false',
          max_vulnerability_management_policies_allowed: 5,
          max_active_vulnerability_management_policies_reached: 'false',
          max_scan_execution_policy_actions: Gitlab::CurrentSettings.scan_execution_policies_action_limit
        }
      end

      before do
        allow(helper).to receive(:timezone_data).with(format: :full).and_return(timezones)
        allow(helper).to receive(:current_user) { owner }
        allow(helper).to receive(:can?).with(owner, :modify_security_policy, project) { true }
      end

      subject(:orchestration_policy_data) { helper.orchestration_policy_data(project, policy_type, policy, approvers) }

      context 'when a new policy is being created' do
        let(:policy) { nil }
        let(:policy_type) { nil }
        let(:approvers) { nil }

        it { is_expected.to match(base_data) }
      end

      context 'when an existing policy is being edited' do
        let(:policy) { build(:scan_execution_policy, name: 'Run DAST in every pipeline') }

        it { is_expected.to match(base_data) }
      end

      context 'when scan policy update is disabled' do
        before do
          allow(helper).to receive(:can?).with(owner, :modify_security_policy, project) { false }
        end

        it { is_expected.to match(base_data.merge(disable_scan_policy_update: 'true')) }
      end

      context 'when a project does have a security policy project' do
        let_it_be(:policy_management_project) { create(:project) }

        let_it_be(:security_orchestration_policy_configuration) do
          create(
            :security_orchestration_policy_configuration,
            security_policy_management_project: policy_management_project, project: project
          )
        end

        it 'include information about policy management project' do
          is_expected.to match(base_data.merge(assigned_policy_project: {
            id: policy_management_project.to_global_id.to_s,
            name: policy_management_project.name,
            full_path: policy_management_project.full_path,
            branch: policy_management_project.default_branch_or_main
          }.to_json))
        end
      end

      it_behaves_like 'loads software_licenses names'
    end

    context 'for namespace' do
      let(:approvers) { { single_approvers: %w[approver1 approver2] } }
      let(:owner) { namespace.first_owner }
      let(:policy) { nil }
      let(:policy_type) { 'scan_execution_policy' }
      let(:base_data) do
        {
          assigned_policy_project: nil.to_json,
          disable_scan_policy_update: 'false',
          policy: policy&.to_json,
          policy_editor_empty_state_svg_path: kind_of(String),
          policy_type: policy_type,
          policies_path: kind_of(String),
          role_approver_types: %w[developer maintainer owner],
          scan_policy_documentation_path: kind_of(String),
          namespace_path: namespace.full_path,
          namespace_id: namespace.id,
          action_approvers: approvers&.to_json,
          software_licenses: kind_of(Array),
          global_group_approvers_enabled:
            Gitlab::CurrentSettings.security_policy_global_group_approvers_enabled.to_json,
          root_namespace_path: namespace.root_ancestor.full_path,
          timezones: timezones.to_json,
          max_active_scan_execution_policies_reached: 'false',
          max_active_pipeline_execution_policies_reached: 'false',
          max_active_scan_result_policies_reached: 'false',
          max_scan_result_policies_allowed: Gitlab::CurrentSettings.security_approval_policies_limit,
          max_scan_execution_policies_allowed: 5,
          max_pipeline_execution_policies_allowed: 5,
          max_ci_component_publishing_policies_allowed: 5,
          max_ci_component_publishing_policies_reached: 'false',
          max_vulnerability_management_policies_allowed: 5,
          max_active_vulnerability_management_policies_reached: 'false',
          max_scan_execution_policy_actions: Gitlab::CurrentSettings.scan_execution_policies_action_limit
        }
      end

      before do
        allow(helper).to receive(:timezone_data).with(format: :full).and_return(timezones)
        allow(helper).to receive(:current_user) { owner }
        allow(helper).to receive(:can?).with(owner, :modify_security_policy, namespace) { true }
      end

      subject(:orchestration_policy_data) do
        helper.orchestration_policy_data(namespace, policy_type, policy, approvers)
      end

      context 'when a new policy is being created' do
        let(:policy) { nil }
        let(:policy_type) { nil }
        let(:approvers) { nil }

        it { is_expected.to match(base_data) }
      end

      context 'when an existing policy is being edited' do
        let(:policy_type) { 'scan_execution_policy' }

        let(:policy) do
          build(:scan_execution_policy, name: 'Run DAST in every pipeline')
        end

        it { is_expected.to match(base_data) }
      end

      context 'when scan policy update is disabled' do
        before do
          allow(helper).to receive(:can?)
            .with(owner, :modify_security_policy, namespace)
            .and_return(false)
        end

        it { is_expected.to match(base_data.merge(disable_scan_policy_update: 'true')) }
      end

      context 'when a namespace does have a security policy project' do
        let_it_be(:policy_management_project) { create(:project) }

        let_it_be(:security_orchestration_policy_configuration) do
          create(
            :security_orchestration_policy_configuration, :namespace,
            security_policy_management_project: policy_management_project, namespace: namespace
          )
        end

        it 'include information about policy management project' do
          is_expected.to match(base_data.merge(assigned_policy_project: {
            id: policy_management_project.to_global_id.to_s,
            name: policy_management_project.name,
            full_path: policy_management_project.full_path,
            branch: policy_management_project.default_branch_or_main
          }.to_json))
        end
      end

      it_behaves_like 'loads software_licenses names'
    end
  end

  shared_examples 'when source does not have a security policy project' do
    it { is_expected.to be_falsey }
  end

  shared_examples 'when source has active scan policies' do |limit_reached: false|
    before do
      allow_next_instance_of(Repository) do |repository|
        allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
      end
    end

    it 'returns if max active scan policies limit was reached' do
      is_expected.to eq(limit_reached)
    end
  end

  shared_examples '#max_active_scan_execution_policies_reached for source' do
    context 'when a source does not have a security policy project' do
      it_behaves_like 'when source does not have a security policy project'
    end

    context 'when a source did not reach the limit of active scan execution policies' do
      it_behaves_like 'when source has active scan policies'
    end

    context 'when a source reached the limit of active scan execution policies' do
      before do
        stub_const('::Security::ScanExecutionPolicy::POLICY_LIMIT', 1)
      end

      it_behaves_like 'when source has active scan policies', limit_reached: true
    end
  end

  describe '#max_active_scan_execution_policies_reached?' do
    let_it_be(:policy_management_project) { create(:project, :repository) }

    let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [build(:scan_execution_policy)]) }

    context 'for project' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration,
          security_policy_management_project: policy_management_project, project: project
        )
      end

      subject { helper.max_active_scan_execution_policies_reached?(project) }

      it_behaves_like '#max_active_scan_execution_policies_reached for source'
    end

    context 'for namespace' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration, :namespace,
          security_policy_management_project: policy_management_project, namespace: namespace
        )
      end

      subject { helper.max_active_scan_execution_policies_reached?(namespace) }

      it_behaves_like '#max_active_scan_execution_policies_reached for source'
    end
  end

  shared_examples '#max_active_ci_component_publishing_policies_reached for source' do
    context 'when a source does not have a security policy project' do
      it { is_expected.to be_falsey }
    end

    context 'when a source did not reach the limit of ci component publishing policies' do
      it_behaves_like 'when source has active scan policies', limit_reached: false
    end

    context 'when a source reached the limit of active ci component publishing policies' do
      before do
        stub_const('::Security::CiComponentPublishingPolicy::POLICY_LIMIT', 1)
      end

      it_behaves_like 'when source has active scan policies', limit_reached: true
    end
  end

  shared_examples '#max_active_vulnerability_management_policies_reached for source' do
    context 'when a source does not have a security policy project' do
      it_behaves_like 'when source does not have a security policy project'
    end

    context 'when a source did not reach the limit of active vulnerability management policies' do
      it_behaves_like 'when source has active scan policies', limit_reached: false
    end

    context 'when a source reached the limit of active vulnerability management policies' do
      before do
        stub_const('::Security::VulnerabilityManagementPolicy::POLICY_LIMIT', 1)
      end

      it_behaves_like 'when source has active scan policies', limit_reached: true
    end
  end

  describe '#max_active_vulnerability_management_policies_reached?' do
    let_it_be(:policy_management_project) { create(:project, :repository) }

    let(:policy_yaml) do
      build(:orchestration_policy_yaml, vulnerability_management_policy: [build(:vulnerability_management_policy)])
    end

    context 'for project' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration,
          security_policy_management_project: policy_management_project, project: project
        )
      end

      subject { helper.max_active_vulnerability_management_policies_reached?(project) }

      it_behaves_like '#max_active_vulnerability_management_policies_reached for source'
    end

    context 'for namespace' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration, :namespace,
          security_policy_management_project: policy_management_project, namespace: namespace
        )
      end

      subject { helper.max_active_vulnerability_management_policies_reached?(namespace) }

      it_behaves_like '#max_active_vulnerability_management_policies_reached for source'
    end
  end

  describe '#max_active_ci_component_publishing_policies_reached?' do
    let_it_be(:policy_management_project) { create(:project, :repository) }

    let(:policy_yaml) do
      build(:orchestration_policy_yaml, ci_component_publishing_policy: [build(:ci_component_publishing_policy)])
    end

    context 'for project' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration,
          security_policy_management_project: policy_management_project, project: project
        )
      end

      subject { helper.max_active_ci_component_publishing_policies_reached?(project) }

      it_behaves_like '#max_active_ci_component_publishing_policies_reached for source'
    end

    context 'for namespace' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration, :namespace,
          security_policy_management_project: policy_management_project, namespace: namespace
        )
      end

      subject { helper.max_active_ci_component_publishing_policies_reached?(namespace) }

      it_behaves_like '#max_active_ci_component_publishing_policies_reached for source'
    end
  end

  shared_examples '#max_active_pipeline_execution_policies_reached for source' do
    context 'when a source does not have a security policy project' do
      it_behaves_like 'when source does not have a security policy project'
    end

    context 'when a source did not reach the limit of active pipeline execution policies' do
      it_behaves_like 'when source has active scan policies', limit_reached: false
    end

    context 'when a source reached the limit of active pipeline execution policies' do
      before do
        stub_const('::Security::PipelineExecutionPolicy::POLICY_LIMIT', 1)
      end

      it_behaves_like 'when source has active scan policies', limit_reached: true
    end
  end

  describe '#max_active_pipeline_execution_policies_reached?' do
    let_it_be(:policy_management_project) { create(:project, :repository) }

    let(:policy_yaml) do
      build(:orchestration_policy_yaml, pipeline_execution_policy: [build(:pipeline_execution_policy)])
    end

    context 'for project' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration,
          security_policy_management_project: policy_management_project, project: project
        )
      end

      subject { helper.max_active_pipeline_execution_policies_reached?(project) }

      it_behaves_like '#max_active_pipeline_execution_policies_reached for source'
    end

    context 'for namespace' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration, :namespace,
          security_policy_management_project: policy_management_project, namespace: namespace
        )
      end

      subject { helper.max_active_pipeline_execution_policies_reached?(namespace) }

      it_behaves_like '#max_active_pipeline_execution_policies_reached for source'
    end
  end

  shared_examples '#max_active_scan_result_policies_reached for source' do
    context 'when a source does not have a security policy project' do
      it_behaves_like 'when source does not have a security policy project'
    end

    context 'when a source did not reach the limit of active scan result policies' do
      it_behaves_like 'when source has active scan policies'
    end

    context 'when a source reached the limit of active scan result policies' do
      before do
        allow(::Gitlab::CurrentSettings).to receive(:security_approval_policies_limit).and_return(1)
      end

      it_behaves_like 'when source has active scan policies', limit_reached: true
    end
  end

  describe '#max_active_scan_result_policies_reached?' do
    let_it_be(:policy_management_project) { create(:project, :repository) }

    let(:policy_yaml) { build(:orchestration_policy_yaml, scan_result_policy: [build(:scan_result_policy)]) }

    context 'for project' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration,
          security_policy_management_project: policy_management_project, project: project
        )
      end

      subject { helper.max_active_scan_result_policies_reached?(project) }

      it_behaves_like '#max_active_scan_result_policies_reached for source'
    end

    context 'for namespace' do
      let_it_be(:security_orchestration_policy_configuration) do
        create(
          :security_orchestration_policy_configuration, :namespace,
          security_policy_management_project: policy_management_project, namespace: namespace
        )
      end

      subject { helper.max_active_scan_result_policies_reached?(namespace) }

      it_behaves_like '#max_active_scan_result_policies_reached for source'
    end
  end

  describe '#security_configurations_preventing_project_deletion' do
    let_it_be(:project) { create(:project) }

    subject(:preventing_configurations) { helper.security_configurations_preventing_project_deletion(project) }

    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    context 'when there are no preventing configurations' do
      it 'is an empty relation' do
        expect(preventing_configurations).to be_empty
      end
    end

    context 'when there are preventing configurations' do
      let_it_be(:config) do
        create(:security_orchestration_policy_configuration, security_policy_management_project: project)
      end

      it 'returns the preventing configurations' do
        expect(preventing_configurations).to contain_exactly(config)
      end

      context 'when security orchestration policies are not available' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'is an empty relation' do
          expect(preventing_configurations).to be_empty
        end
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(reject_security_policy_project_deletion: false)
        end

        it 'is an empty relation' do
          expect(preventing_configurations).to be_empty
        end
      end
    end
  end

  describe '#security_configurations_preventing_group_deletion' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let(:feature_licensed) { true }

    subject(:preventing_configurations) { helper.security_configurations_preventing_group_deletion(group) }

    before do
      stub_licensed_features(security_orchestration_policies: feature_licensed)
    end

    context 'when security orchestration policies are not available' do
      let(:feature_licensed) { false }

      it 'is an empty relation' do
        expect(preventing_configurations).to be_empty
      end
    end

    context 'when there are no preventing configurations' do
      it 'is an empty relation' do
        expect(preventing_configurations).to be_empty
      end
    end

    context 'when there are preventing configurations' do
      let!(:config) do
        create(:security_orchestration_policy_configuration, security_policy_management_project: project)
      end

      it 'returns the preventing configurations' do
        expect(preventing_configurations).to contain_exactly(config)
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(reject_security_policy_project_deletion_groups: false)
      end

      it 'is an empty relation' do
        expect(preventing_configurations).to be_empty
      end
    end
  end
end
