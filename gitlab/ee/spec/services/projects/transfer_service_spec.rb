# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::TransferService, feature_category: :groups_and_projects do
  include EE::GeoHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public, owners: user) }
  let_it_be_with_refind(:project) { create(:project, :repository, :public, :legacy_storage, namespace: user.namespace) }

  subject { described_class.new(project, user) }

  context 'audit events' do
    include_examples 'audit event logging' do
      let(:fail_condition!) do
        expect(project).to receive(:has_container_registry_tags?).and_return(true)

        def operation
          subject.execute(group)
        end
      end

      let(:attributes) do
        {
           author_id: user.id,
           entity_id: project.id,
           entity_type: 'Project',
           details: {
             change: 'namespace',
             event_name: "project_namespace_updated",
             from: project.old_path_with_namespace,
             to: project.full_path,
             author_name: user.name,
             author_class: user.class.name,
             target_id: project.id,
             target_type: 'Project',
             target_details: project.full_path,
             custom_message: "Changed namespace from #{project.old_path_with_namespace} to #{project.full_path}"
           }
         }
      end
    end
  end

  context 'missing epics applied to issues' do
    it 'delegates transfer to Epics::TransferService' do
      expect_next_instance_of(Epics::TransferService, user, project.group, project) do |epics_transfer_service|
        expect(epics_transfer_service).to receive(:execute).once.and_call_original
      end

      subject.execute(group)
    end
  end

  describe 'elasticsearch indexing' do
    context 'when we transfer from group_namespace to group_namespace' do
      let_it_be(:new_group) { create(:group) }
      let_it_be(:project) { create(:project, namespace: group) }

      before do
        new_group.add_owner(user)
      end

      it 'call to ::Search::Elastic::DeleteWorker to remove duplicate work items' do
        expect(project.namespace).to eq(group)
        expect(::Search::Elastic::DeleteWorker).to receive(:perform_async).with({
          task: :delete_project_associations,
          project_id: project.id,
          traversal_id: new_group.elastic_namespace_ancestry
        }).once

        subject.execute(new_group)
        expect(project.namespace).to eq(new_group)
      end
    end

    context 'when we transfer from group_namespace to user_namespace' do
      let_it_be(:project) { create(:project, namespace: group) }

      it 'call to ::Search::Elastic::DeleteWorker to remove duplicate work items' do
        expect(project.namespace).to eq(group)
        expect(::Search::Elastic::DeleteWorker).to receive(:perform_async).with({
          task: :delete_project_associations,
          project_id: project.id,
          traversal_id: user.namespace.elastic_namespace_ancestry
        }).once

        subject.execute(user.namespace)
        expect(project.namespace).to eq(user.namespace)
      end
    end

    context 'when we transfer from user_namespace to group_namespace' do
      it 'call to ::Search::Elastic::DeleteWorker to remove duplicate work items' do
        expect(project.namespace).to eq(user.namespace)
        expect(::Search::Elastic::DeleteWorker).to receive(:perform_async).with({
          task: :delete_project_associations,
          project_id: project.id,
          traversal_id: group.elastic_namespace_ancestry
        }).once

        subject.execute(group)
        expect(project.namespace).to eq(group)
      end
    end

    context 'when we transfer from user_namespace to user_namespace' do
      let_it_be(:new_user) { create(:user) }

      before do
        project.add_owner(new_user)
      end

      it 'call to ::Search::Elastic::DeleteWorker to remove duplicate work items' do
        expect(project.namespace).to eq(user.namespace)
        expect(::Search::Elastic::DeleteWorker).to receive(:perform_async).with({
          task: :delete_project_associations,
          project_id: project.id,
          traversal_id: new_user.namespace.elastic_namespace_ancestry
        }).once

        described_class.new(project, new_user).execute(new_user.namespace)
        expect(project.namespace).to eq(new_user.namespace)
      end
    end

    it 'delegates transfer to Elastic::ProjectTransferWorker and ::Search::Zoekt::ProjectTransferWorker' do
      expect(::Elastic::ProjectTransferWorker).to receive(:perform_async).with(project.id, project.namespace.id, group.id).once
      expect(::Search::Zoekt::ProjectTransferWorker).to receive(:perform_async).with(project.id, project.namespace.id).once

      subject.execute(group)
    end
  end

  describe 'security policy project', feature_category: :security_policy_management do
    context 'when project has policy project' do
      let!(:configuration) { create(:security_orchestration_policy_configuration, project: project) }

      it 'unassigns the policy project', :sidekiq_inline do
        subject.execute(group)

        expect { configuration.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      end
    end

    context 'when project has inherited policy project' do
      let_it_be(:group, reload: true) { create(:group) }
      let_it_be(:sub_group, reload: true) { create(:group, parent: group) }
      let_it_be(:group_configuration, reload: true) { create(:security_orchestration_policy_configuration, project: nil, namespace: group) }
      let_it_be(:sub_group_configuration, reload: true) { create(:security_orchestration_policy_configuration, project: nil, namespace: sub_group) }

      let!(:group_approval_rule) { create(:approval_project_rule, :scan_finding, :requires_approval, project: project, security_orchestration_policy_configuration: group_configuration) }
      let!(:sub_group_approval_rule) { create(:approval_project_rule, :scan_finding, :requires_approval, project: project, security_orchestration_policy_configuration: sub_group_configuration) }

      before do
        stub_licensed_features(security_orchestration_policies: true)
        allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
        end
      end

      context 'when transferring the project within the same hierarchy' do
        before do
          sub_group.add_owner(user)
        end

        it 'deletes scan_finding_rules for inherited policy project' do
          subject.execute(sub_group)

          expect(project.approval_rules).to be_empty
          expect { group_approval_rule.reload }.to raise_exception(ActiveRecord::RecordNotFound)
          expect { sub_group_approval_rule.reload }.to raise_exception(ActiveRecord::RecordNotFound)
        end

        it 'triggers Security::SyncProjectPoliciesWorker for all configurations' do
          expect(Security::SyncProjectPoliciesWorker).to receive(:perform_async).once.with(project.id, group_configuration.id)
          expect(Security::SyncProjectPoliciesWorker).to receive(:perform_async).once.with(project.id, sub_group_configuration.id)

          subject.execute(sub_group)
        end
      end

      context 'when transferring the project from one hierarchy to another' do
        let_it_be(:other_group, reload: true) { create(:group) }

        before do
          project.update!(group: sub_group)
          other_group.add_owner(user)
        end

        it 'deletes scan_finding_rules for inherited policy project' do
          subject.execute(other_group)

          expect(project.approval_rules).to be_empty
          expect { group_approval_rule.reload }.to raise_exception(ActiveRecord::RecordNotFound)
        end

        it 'triggers Security::ScanResultPolicies::SyncProjectWorker to sync new group policies' do
          expect(Security::ScanResultPolicies::SyncProjectWorker).to receive(:perform_async).with(project.id)

          subject.execute(other_group)
        end
      end
    end
  end

  describe 'updating paid features' do
    it 'calls the ::EE::Projects::RemovePaidFeaturesService to update paid features' do
      expect_next_instance_of(::EE::Projects::RemovePaidFeaturesService, project) do |service|
        expect(service).to receive(:execute).with(group).and_call_original
      end

      subject.execute(group)
    end

    # explicit testing of the pipeline subscriptions cleanup to verify `run_after_commit` block is executed
    context 'with pipeline subscriptions', :saas do
      before do
        create(:license, plan: License::PREMIUM_PLAN)
        stub_ee_application_setting(should_check_namespace_plan: true)
      end

      context 'when target namespace has a free plan' do
        it 'schedules cleanup for upstream project subscription' do
          expect(::Ci::UpstreamProjectsSubscriptionsCleanupWorker).to receive(:perform_async)
            .with(project.id)
            .and_call_original

          subject.execute(group)
        end
      end
    end
  end

  describe 'deleting compliance framework setting' do
    context 'when the project has a compliance framework setting' do
      let!(:compliance_framework_setting) { create(:compliance_framework_project_setting, project: project) }

      context 'when the project is transferring under the same top level group' do
        let_it_be(:project) { create(:project, group: group) }
        let_it_be(:sub_group) { create(:group, parent: group) }

        it 'does not delete the compliance framework setting' do
          subject.execute(sub_group)

          expect(project.reload.compliance_framework_settings).to eq([compliance_framework_setting])
        end
      end

      context 'when the project is transferring under a nested sub group' do
        let_it_be(:sub_group) { create(:group, parent: create(:group, :public)) }
        let_it_be(:project) { create(:project, group: sub_group) }
        let_it_be(:nested_sub_group) { create(:group, parent: sub_group) }

        before do
          sub_group.add_owner(user)
        end

        it 'does not delete the compliance framework setting' do
          subject.execute(nested_sub_group)

          expect(project.reload.compliance_framework_settings).to eq([compliance_framework_setting])
        end
      end

      context 'when the project is transferring to a new group' do
        let_it_be(:old_group) { create(:group, :public) }
        let_it_be_with_reload(:project) { create(:project, group: old_group) }

        before do
          old_group.add_owner(user)
          stub_licensed_features(extended_audit_events: true, external_audit_events: true)
        end

        it 'deletes the compliance framework setting' do
          subject.execute(group)

          expect(project.reload.compliance_framework_settings).to eq([])
        end

        it 'creates an audit event' do
          expect { subject.execute(group) }.to change { AuditEvent.count }.by(2)

          expect(AuditEvent.last.details[:event_name]).to eq("compliance_framework_deleted")
        end
      end
    end

    context 'when the project does not have a compliance framework setting' do
      it 'does not raise an error' do
        expect { subject.execute(group) }.not_to raise_error
      end

      it 'does not change the compliance framework settings count' do
        expect { subject.execute(group) }.not_to change { ::ComplianceManagement::ComplianceFramework::ProjectSettings.count }
      end
    end
  end

  context 'update_compliance_standards_adherence' do
    let_it_be(:old_group) { create(:group) }
    let_it_be(:project) { create(:project, group: old_group) }
    let!(:adherence) { create(:compliance_standards_adherence, :gitlab, project: project) }

    before do
      stub_licensed_features(group_level_compliance_dashboard: true)
      old_group.add_owner(user)
    end

    it "updates the project's compliance standards adherence with new namespace id" do
      expect(project.compliance_standards_adherence.first.namespace_id).to eq(old_group.id)

      subject.execute(group)

      expect(project.reload.compliance_standards_adherence.first.namespace_id).to eq(group.id)
    end
  end
end
