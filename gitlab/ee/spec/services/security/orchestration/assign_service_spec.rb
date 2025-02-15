# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Orchestration::AssignService, feature_category: :security_policy_management do
  let_it_be(:project, reload: true) { create(:project) }
  let_it_be(:another_project) { create(:project) }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:namespace, reload: true) { create(:group) }
  let_it_be(:another_namespace) { create(:group) }

  let_it_be(:policy_project) { create(:project) }
  let_it_be(:new_policy_project) { create(:project) }

  let(:container) { project }
  let(:another_container) { another_project }

  describe '#execute' do
    subject(:service) do
      described_class.new(container: container, current_user: current_user, params: { policy_project_id: policy_project.id }).execute
    end

    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    shared_context 'when policy project is already inherited' do
      let(:parent_group) { create(:group) }

      before do
        allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 3) do |configuration|
          allow(configuration).to receive(:policy_configuration_valid?).and_return(true)
        end

        parent_group.add_owner(current_user)

        case container
        when Project then container.update!(group: parent_group)
        when Group then container.update!(parent: parent_group)
        end

        container.reload

        Security::OrchestrationPolicyConfiguration.create!(
          security_policy_management_project_id: policy_project.id,
          namespace_id: parent_group.id)
      end
    end

    shared_examples 'executes assign service' do
      it 'raises AccessDeniedError if user does not have permission' do
        expect { service }.to raise_error Gitlab::Access::AccessDeniedError
      end

      context 'with developer access' do
        before do
          container.add_developer(current_user)
        end

        it 'raises AccessDeniedError if user does not have permission' do
          expect { service }.to raise_error Gitlab::Access::AccessDeniedError
        end
      end

      context 'with owner access' do
        before do
          container.add_owner(current_user)
          another_container.add_owner(current_user)

          # Create or update to policy project requires minimum commit access to policy project.
          policy_project.add_developer(current_user)
        end

        context 'when policy project is assigned' do
          it 'assigns policy project to container and logs audit event' do
            audit_context = {
              name: "policy_project_updated",
              author: current_user,
              scope: container,
              target: policy_project,
              message: "Linked #{policy_project.name} as the security policy project"
            }
            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)
            expect(Security::SyncScanPoliciesWorker).to receive(:perform_async)

            expect(service).to be_success

            expect(
              container.security_orchestration_policy_configuration.security_policy_management_project_id
            ).to eq(policy_project.id)
          end

          it 'assigns same policy to different container' do
            repeated_service =
              described_class.new(container: another_container, current_user: current_user, params: { policy_project_id: policy_project.id }).execute
            expect(repeated_service).to be_success
          end

          context 'when policy project is already inherited' do
            include_context 'when policy project is already inherited'

            it 'errors' do
              expect(service.to_h.slice(:status, :message).values).to match_array([:error, "You don't need to link the security policy projects from the group. All policies in the security policy projects are inherited already."])
            end

            context 'when already inherited configuration is invalid' do
              before do
                allow_next_found_instances_of(Security::OrchestrationPolicyConfiguration, 3) do |configuration|
                  allow(configuration).to receive(:policy_configuration_valid?).and_return(false)
                end
              end

              it 'errors' do
                expect(service.to_h.slice(:status, :message).values).to match_array([:error, "You don't need to link the security policy projects from the group. All policies in the security policy projects are inherited already."])
              end
            end
          end
        end

        context 'when policy project is unassigned' do
          before do
            service
          end

          let(:repeated_service) { described_class.new(container: container, current_user: current_user, params: { policy_project_id: nil }).execute }

          it 'unassigns project', :sidekiq_inline do
            expect { repeated_service }.to change {
              container.reload.security_orchestration_policy_configuration
            }.to(nil)
          end

          it 'logs audit event', :sidekiq_inline do
            old_policy_project = container.security_orchestration_policy_configuration.security_policy_management_project
            audit_context = {
              name: "policy_project_updated",
              author: current_user,
              scope: container,
              target: old_policy_project,
              message: "Unlinked #{old_policy_project.name} as the security policy project"
            }

            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

            if container.is_a?(Project)
              expect(::Gitlab::Audit::Auditor).to receive(:audit).with(include(name: "user_destroyed")) # policy bot user
            end

            repeated_service
          end

          context 'when policy project is inherited' do
            include_context 'when policy project is already inherited'

            it 'succeeds' do
              expect(service).to be_success
            end
          end
        end

        context 'when policy project is reassigned' do
          before do
            service
          end

          let(:repeated_service) { described_class.new(container: container, current_user: current_user, params: { policy_project_id: new_policy_project.id }).execute }

          it 'updates container with new policy project' do
            expect(repeated_service).to be_success
            expect(
              container.security_orchestration_policy_configuration.security_policy_management_project_id
            ).to eq(new_policy_project.id)
          end

          it 'logs audit event and calls SyncScanPoliciesWorker' do
            old_policy_project = container.security_orchestration_policy_configuration.security_policy_management_project
            audit_context = {
              name: "policy_project_updated",
              author: current_user,
              scope: container,
              target: new_policy_project,
              message: "Changed the linked security policy project from #{old_policy_project.name} to #{new_policy_project.name}"
            }

            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)
            expect(Security::SyncScanPoliciesWorker).to receive(:perform_async).with(container.security_orchestration_policy_configuration.id)

            repeated_service
          end
        end

        context 'when failure in db' do
          let(:repeated_service) { described_class.new(container: container, current_user: current_user, params: { policy_project_id: new_policy_project.id }).execute }

          before do
            dbl_error = double('ActiveRecord')
            dbl =
              double(
                'Security::OrchestrationPolicyConfiguration',
                security_orchestration_policy_configuration: dbl_error,
                all_security_orchestration_policy_configurations: [],
                id: non_existing_record_id
              )

            allow(current_user).to receive(:can?).with(:update_security_orchestration_policy_project, dbl).and_return(true)
            allow(dbl_error).to receive(:security_policy_management_project).and_return(policy_project)
            allow(dbl_error).to receive(:transaction).and_yield
            allow(dbl_error).to receive(:delete_scan_finding_rules).and_return(nil)
            allow(dbl_error).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)

            allow_next_instance_of(described_class) do |instance|
              allow(instance).to receive(:has_existing_policy?).and_return(true)
              allow(instance).to receive(:container).and_return(dbl)
            end
          end

          it 'returns error when db has problem' do
            expect(repeated_service).to be_error
          end

          it 'does not log audit event' do
            expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

            repeated_service
          end

          it 'does not call SyncScanPoliciesWorker' do
            expect(Security::SyncScanPoliciesWorker).not_to receive(:perform_async)

            repeated_service
          end
        end

        describe 'with invalid project id' do
          subject(:service) { described_class.new(container: container, current_user: current_user, params: { policy_project_id: non_existing_record_id }).execute }

          it 'does not change policy project' do
            expect(service).to be_error

            expect { service }.not_to change { container.security_orchestration_policy_configuration }
          end

          it 'does not log audit event' do
            expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

            service
          end
        end
      end
    end

    shared_examples 'triggers bot user create worker' do
      context 'with owner access' do
        before do
          container.add_owner(current_user)
        end

        it 'triggers the project bot user create worker' do
          expected_projects.each do |expected_project|
            expect(Security::OrchestrationConfigurationCreateBotWorker).to receive(:perform_async).with(expected_project.id, current_user.id)
          end

          expect(service).to be_success
        end
      end
    end

    context 'for project' do
      let(:container) { project }
      let(:another_container) { another_project }

      it_behaves_like 'executes assign service'
      it_behaves_like 'triggers bot user create worker' do
        let!(:expected_projects) { [container] }
      end
    end

    context 'for namespace' do
      let(:container) { namespace }
      let(:another_container) { another_namespace }

      it_behaves_like 'executes assign service'
      it_behaves_like 'triggers bot user create worker' do
        let!(:expected_projects) { create_list(:project, 2, group: container) }
      end

      describe 'redundant policy configurations within namespace' do
        before do
          container.add_owner(current_user)
        end

        it 'unassigns redundant configurations' do
          expect(::Security::UnassignRedundantPolicyConfigurationsWorker).to receive(:perform_async).with(container.id, policy_project.id, current_user.id)

          service
        end
      end
    end
  end
end
