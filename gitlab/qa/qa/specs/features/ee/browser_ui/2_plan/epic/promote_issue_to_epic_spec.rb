# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', product_group: :product_planning do
    describe 'promote issue to epic' do
      include_context 'work item epics migration'

      let(:project) do
        create(:project, name: 'promote-issue-to-epic', description: 'Project to promote issue to epic')
      end

      let(:issue) { create(:issue, project: project) }

      before do
        Flow::Login.sign_in
      end

      it 'promotes issue to epic', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347970' do
        issue.visit!

        Page::Project::Issue::Show.perform do |show|
          # Due to the randomness of tests execution, sometimes a previous test
          # may have changed the filter, which makes the below action needed.
          # TODO: Make this test completely independent, not requiring the below step.
          show.select_all_activities_filter
          # We add a space together with the '/promote' string to avoid test flakiness
          # due to the tooltip '/promote Promote issue to an epic (may expose
          # confidential information)' from being shown, which may cause the click not
          # to work properly.
          show.comment('/promote ')
        end

        work_item_epics_enabled = work_item_epics_enabled_for_group?(project.group)

        project.group.visit!
        Page::Group::Menu.perform(&:go_to_epics)

        if work_item_epics_enabled
          QA::EE::Page::Group::WorkItem::Epic::Index.perform do |index|
            expect(index).to have_epic_title(issue.title)
          end
        else
          QA::EE::Page::Group::Epic::Index.perform do |index|
            expect(index).to have_epic_title(issue.title)
          end
        end
      end
    end
  end
end
