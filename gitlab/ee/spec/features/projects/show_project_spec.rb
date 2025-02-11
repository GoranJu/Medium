# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project show page', :feature, feature_category: :groups_and_projects do
  include BillableMembersHelpers

  let_it_be(:user) { create(:user) }

  describe 'stat button existence' do
    describe 'populated project' do
      let(:project) { create(:project, :public, :repository) }

      describe 'as a maintainer' do
        before do
          project.add_maintainer(user)
          sign_in(user)

          visit project_path(project)
        end

        it '"Kubernetes cluster" button linked to clusters page' do
          create(:cluster, :provided_by_gcp, projects: [project])
          create(:cluster, :provided_by_gcp, :production_environment, projects: [project])

          visit project_path(project)

          page.within('.project-buttons') do
            expect(page).to have_link('Kubernetes', href: project_clusters_path(project))
          end
        end
      end
    end
  end

  describe 'pull mirroring information' do
    let_it_be(:project) do
      create(:project, :repository, mirror: true, mirror_user: user, import_url: 'http://user:pass@test.com')
    end

    context 'for maintainer' do
      before do
        project.add_maintainer(user)
        sign_in(user)

        visit project_path(project)
      end

      it 'displays mirrored from url' do
        expect(page).to have_content("Mirrored from http://*****:*****@test.com")
      end
    end

    context 'for guest' do
      before do
        project.add_guest(user)
        sign_in(user)

        visit project_path(project)
      end

      it 'does not display mirrored from url' do
        expect(page).not_to have_content("Mirrored from http://*****:*****@test.com")
      end
    end
  end

  context 'when over free user limit', :saas do
    subject(:visit_page) { visit project_path(project) }

    context 'with group namespace' do
      let(:role) { :owner }
      let_it_be_with_refind(:group) { create(:group_with_plan, :private, plan: :free_plan) }

      before do
        group.add_member(user, role)
        sign_in(user)
      end

      context 'with repository' do
        let_it_be(:project) { create(:project, :repository, :private, group: group) }

        it_behaves_like 'over the free user limit alert'
      end

      context 'with empty repository' do
        let_it_be(:project) { create(:project, :empty_repo, :private, group: group) }

        it_behaves_like 'over the free user limit alert'
      end

      context 'without repository' do
        let_it_be(:project) { create(:project, :private, group: group) }

        it_behaves_like 'over the free user limit alert'
      end
    end
  end

  context "when user has no permissions" do
    let_it_be(:project) { create(:project, :public, :repository) }

    it 'does not render settings button if user has no permissions', :js do
      visit project_path(project)

      find_by_testid('groups-projects-more-actions-dropdown').click

      expect(page).not_to have_selector('[data-testid="project-settings-link"]')
    end

    it 'renders settings button if user has permissions', :js do
      project.add_maintainer(user)
      sign_in(user)
      visit project_path(project)

      find_by_testid('groups-projects-more-actions-dropdown').click

      expect(page).to have_selector('[data-testid="settings-project-link"]')
    end
  end

  describe 'all seats used alert', :saas, :use_clean_rails_memory_store_caching do
    let_it_be_with_refind(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }

    before do
      group.add_member(create(:user), GroupMember::DEVELOPER)
      group.namespace_settings.update!(seat_control: :block_overages)
      sign_in(user)
    end

    context 'when all seats are used' do
      let_it_be(:subscription) { create(:gitlab_subscription, :premium, namespace: group, seats: 1) }

      context 'when the user is an owner' do
        before do
          stub_billable_members_reactive_cache(group)

          group.add_owner(user)
        end

        it 'displays the all seats used alert' do
          visit project_path(project)

          expect(page).to have_css '[data-testid="all-seats-used-alert"].gl-alert-warning'

          within_testid('all-seats-used-alert') do
            expect(page).to have_css('[data-testid="close-icon"]')
            expect(page).to have_text "No more seats in subscription"
            expect(page).to have_text "Your namespace has used all the seats in your subscription and users can " \
                                      "no longer be invited or added to the namespace."
            expect(page).to have_link 'Purchase more seats', href:
              help_page_path('subscriptions/gitlab_com/_index.md', anchor: 'add-seats-to-subscription')
          end
        end
      end

      context 'when the user is not an owner' do
        let(:role) { :developer }

        it 'does not display the all seats used alert' do
          visit project_path(project)

          expect(page).not_to have_css '[data-testid="all-seats-used-alert"].gl-alert-warning'
        end
      end
    end

    context 'with a free plan' do
      let_it_be(:subscription) { create(:gitlab_subscription, :free, namespace: group, seats: 1) }

      before do
        stub_billable_members_reactive_cache(group)
      end

      it 'does not display the all seats used alert' do
        visit project_path(project)

        expect(page).not_to have_css '[data-testid="all-seats-used-alert"].gl-alert-warning'
      end
    end

    context 'when not all seats are used' do
      let_it_be(:subscription) { create(:gitlab_subscription, :premium, namespace: group, seats: 3) }

      before do
        stub_billable_members_reactive_cache(group)
      end

      it 'does not display the all seats used alert' do
        visit project_path(project)

        expect(page).not_to have_css '[data-testid="all-seats-used-alert"].gl-alert-warning'
      end
    end
  end
end
