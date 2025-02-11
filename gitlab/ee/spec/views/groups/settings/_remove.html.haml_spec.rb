# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/_remove.html.haml' do
  let(:group) { create(:group) }
  let_it_be(:policy_project) { create(:project, name: 'Security Policy Project') }
  let_it_be(:linked_project) { create(:project, name: 'Linked Project') }
  let(:linked_configurations) do
    [
      build_stubbed(:security_orchestration_policy_configuration,
        security_policy_management_project: policy_project,
        project: linked_project
      )
    ]
  end

  describe 'render' do
    before do
      allow(group).to receive(:licensed_feature_available?).and_return(false)
      allow(view).to receive(:security_configurations_preventing_group_deletion).and_return(linked_configurations)
      allow(linked_configurations).to receive_messages(exists?: false, any?: false)
    end

    it 'enables the Remove group button and does not show an alert for a group' do
      render 'groups/settings/remove', group: group

      expect(rendered).to have_selector '[data-button-testid="remove-group-button"]'
      expect(rendered).not_to match 'data-disabled="true"'
      expect(rendered).not_to have_selector '[data-testid="group-has-linked-subscription-alert"]'
    end

    it 'disables the Remove group button and shows an alert for a group with a paid gitlab.com plan', :saas do
      create(:gitlab_subscription, :ultimate, namespace: group)

      render 'groups/settings/remove', group: group

      expect(rendered).to have_selector '[data-button-testid="remove-group-button"]'
      expect(rendered).to match 'data-disabled="true"'
      expect(rendered).to have_selector '[data-testid="group-has-linked-subscription-alert"]'
    end

    it 'disables the Remove group button and shows an alert for a group with a legacy paid gitlab.com plan', :saas do
      create(:gitlab_subscription, :gold, namespace: group)

      render 'groups/settings/remove', group: group

      expect(rendered).to have_selector '[data-button-testid="remove-group-button"]'
      expect(rendered).to match 'data-disabled="true"'
      expect(rendered).to have_selector '[data-testid="group-has-linked-subscription-alert"]'
    end

    it 'enables the Remove group button and does not show an alert for a subgroup', :saas do
      create(:gitlab_subscription, :ultimate, namespace: group)
      subgroup = create(:group, parent: group)

      render 'groups/settings/remove', group: subgroup

      expect(rendered).to have_selector '[data-button-testid="remove-group-button"]'
      expect(rendered).not_to match 'data-disabled="true"'
      expect(rendered).not_to have_selector '[data-testid="group-has-linked-subscription-alert"]'
    end

    it 'enables the Remove group button for group with a trial plan', :saas do
      create(:gitlab_subscription, :ultimate_trial, :active_trial, namespace: group)
      render 'groups/settings/remove', group: group

      expect(rendered).to have_selector '[data-button-testid="remove-group-button"]'
      expect(rendered).not_to match 'data-disabled="true"'
      expect(rendered).not_to have_selector '[data-testid="group-has-linked-subscription-alert"]'
    end

    context 'when delayed deletes are enabled' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
      end

      it 'enables the Remove group button and does not show an alert for a group without a paid gitlab.com plan' do
        render 'groups/settings/remove', group: group

        expect(rendered).to have_selector '[data-button-testid="remove-group-button"]'
        expect(rendered).not_to match 'data-disabled="true"'
        expect(rendered).not_to have_selector '[data-testid="group-has-linked-subscription-alert"]'
      end

      it 'disables the Remove group button and shows an alert for a group with a paid gitlab.com plan', :saas do
        create(:gitlab_subscription, :ultimate, namespace: group)

        render 'groups/settings/remove', group: group

        expect(rendered).to have_selector '[data-button-testid="remove-group-button"]'
        expect(rendered).to match 'data-disabled="true"'
        expect(rendered).to have_selector '[data-testid="group-has-linked-subscription-alert"]'
      end

      it 'enables the Remove group button and does not show an alert for a subgroup', :saas do
        create(:gitlab_subscription, :ultimate, namespace: group)
        subgroup = create(:group, parent: group)

        render 'groups/settings/remove', group: subgroup

        expect(rendered).to have_selector '[data-button-testid="remove-group-button"]'
        expect(rendered).not_to match 'data-disabled="true"'
        expect(rendered).not_to have_selector '[data-testid="group-has-linked-subscription-alert"]'
      end
    end
  end

  context 'when group has linked security policy projects' do
    before do
      allow(group).to receive(:licensed_feature_available?).and_return(true)
      allow(view).to receive(:security_configurations_preventing_group_deletion).and_return(linked_configurations)
      allow(linked_configurations).to receive_messages(exists?: true, any?: true)
    end

    it 'disables the remove group button' do
      render 'groups/settings/remove', group: group

      expect(rendered).to have_selector '[data-button-testid="remove-group-button"]'
      expect(rendered).to match 'data-disabled="true"'
    end

    it 'shows the message about linked security policy projects' do
      render 'groups/settings/remove', group: group

      expect(rendered).to have_content(
        "Group cannot be deleted because it has projects " \
          "that are linked as a security policy project"
      )
    end

    it 'lists the linked projects and their configurations' do
      render 'groups/settings/remove', group: group

      expect(rendered).to have_content policy_project.full_path
      expect(rendered).to have_content linked_project.name
    end

    it 'does not show the subscription alert' do
      render 'groups/settings/remove', group: group

      expect(rendered).not_to have_selector '[data-testid="group-has-linked-subscription-alert"]'
    end
  end
end
