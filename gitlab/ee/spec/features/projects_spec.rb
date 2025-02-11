# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project', :js, feature_category: :groups_and_projects do
  def confirm_deletion(project)
    fill_in 'confirm_name_input', with: project.path_with_namespace
    click_button 'Yes, delete project'
    wait_for_requests
  end

  def deletion_date
    (Time.now.utc + ::Gitlab::CurrentSettings.deletion_adjourned_period.days).strftime('%F')
  end

  describe 'delete project' do
    let_it_be(:group_settings) { create(:namespace_settings) }
    let_it_be(:group) { create(:group, :public, namespace_settings: group_settings) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:project_2) { create(:project, group: group) }
    let_it_be(:user) { create(:user) }

    before do
      stub_application_setting(deletion_adjourned_period: 7)
      group.add_owner(user)
    end

    shared_examples 'delayed deletion that is restorable' do
      it 'deletes project delayed and is restorable', :freeze_time do
        deletion_adjourned_period = ::Gitlab::CurrentSettings.deletion_adjourned_period

        expect(page).to have_content("This action will place this project, including all its resources, in a pending deletion state for #{deletion_adjourned_period} days, and delete it permanently on #{deletion_date}.")

        click_button "Delete project"

        expect(page).to have_content("This project can be restored until #{deletion_date}.")

        confirm_deletion(project_to_delete)

        expect(page).to have_content("This project is pending deletion, and will be deleted on #{deletion_date}. Repository and other project resources are read-only.")

        visit removed_dashboard_projects_path

        expect(page).to have_content(project_to_delete.name_with_namespace)
      end
    end

    context 'when adjourned_deletion_for_projects_and_groups is enabled at the instance level' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
      end

      context 'when on GitLab SaaS', :saas do
        before do
          stub_ee_application_setting(should_check_namespace_plan: true)
        end

        context 'when adjourned_deletion_for_projects_and_groups is enabled at the namespace level' do
          let_it_be(:ultimate_group) { create(:group_with_plan, plan: :ultimate_plan) }
          let_it_be(:ultimate_project) { create(:project, group: ultimate_group) }
          let(:project_to_delete) { ultimate_project }

          before do
            ultimate_group.add_owner(user)
            sign_in user
            visit edit_project_path(ultimate_project)
          end

          it_behaves_like 'delayed deletion that is restorable'
        end

        context 'when adjourned_deletion_for_projects_and_groups is not enabled at the namespace level (free project)' do
          context 'when your_work_projects_vue feature flag is enabled' do
            before do
              sign_in user
              visit edit_project_path(project)
            end

            it 'deletes project delayed and is not restorable', :freeze_time do
              expect(page).to have_content("This action will permanently delete this project, including all its resources.")

              click_button "Delete project"

              expect(page).not_to have_content(/This project can be restored/)

              confirm_deletion(project)
              click_link 'Inactive'

              expect(page).not_to have_content(project.name_with_namespace)
            end
          end

          context 'when your_work_projects_vue feature flag is disabled' do
            before do
              stub_feature_flags(your_work_projects_vue: false)
              sign_in user
              visit edit_project_path(project)
            end

            it 'deletes project delayed and is not restorable', :freeze_time do
              expect(page).to have_content("This action will permanently delete this project, including all its resources.")

              click_button "Delete project"

              expect(page).not_to have_content(/This project can be restored/)

              confirm_deletion(project)
              click_link 'Pending deletion'

              expect(page).not_to have_content(project.name_with_namespace)
            end
          end
        end
      end

      context 'when on GitLab self-managed' do
        let(:project_to_delete) { project }

        before do
          sign_in user
          visit edit_project_path(project)
        end

        it_behaves_like 'delayed deletion that is restorable'
      end
    end

    context 'when adjourned_deletion_for_projects_and_groups is not enabled at the instance level' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
        sign_in user
        visit edit_project_path(project)
      end

      it 'deletes project immediately', :sidekiq_inline do
        expect(page).to have_content("This action will permanently delete this project, including all its resources.")

        click_button "Delete project"

        expect(page).not_to have_content(/This project can be restored/)

        confirm_deletion(project)

        expect(page).not_to have_content(project.name_with_namespace)
      end
    end
  end

  describe 'storage pre_enforcement alert', :js do
    include NamespaceStorageHelpers

    let_it_be_with_refind(:group) { create(:group, :with_root_storage_statistics) }
    let_it_be_with_refind(:user) { create(:user) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:storage_banner_text) { "A namespace storage limit of 5 GiB will soon be enforced" }

    before do
      stub_ee_application_setting(automatic_purchased_storage_allocation: true)
      stub_saas_features(namespaces_storage_limit: true)
      set_notification_limit(group, megabytes: 1000)
      set_dashboard_limit(group, megabytes: 5_120)

      group.root_storage_statistics.update!(
        storage_size: 5.gigabytes
      )
      group.add_maintainer(user)
      sign_in(user)
    end

    context 'when storage is over the notification limit' do
      it 'displays the alert in the project page' do
        visit project_path(project)

        expect(page).to have_text storage_banner_text
      end

      context 'when in a subgroup project page' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be(:project) { create(:project, namespace: subgroup) }

        it 'displays the alert' do
          visit project_path(project)

          expect(page).to have_text storage_banner_text
        end
      end

      context 'when in a user namespace project page' do
        let_it_be_with_refind(:project) { create(:project, namespace: user.namespace) }

        before do
          create(
            :namespace_root_storage_statistics,
            namespace: user.namespace,
            storage_size: 5.gigabytes
          )
        end

        it 'displays the alert' do
          visit project_path(project)

          expect(page).to have_text storage_banner_text
        end
      end

      it 'does not display the alert in a paid group project page' do
        allow_next_found_instance_of(Group) do |group|
          allow(group).to receive(:paid?).and_return(true)
        end

        visit project_path(project)

        expect(page).not_to have_text storage_banner_text
      end
    end

    context 'when storage is under the notification limit ' do
      before do
        set_notification_limit(group, megabytes: 10_000)
      end

      it 'does not display the alert in the group page' do
        visit project_path(project)

        expect(page).not_to have_text storage_banner_text
      end
    end
  end
end
