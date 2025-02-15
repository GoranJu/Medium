# frozen_string_literal: true

module QA
  RSpec.describe 'Data Stores' do
    describe 'Group with members', product_group: :tenant_scale do
      let(:source_group_with_members) { create(:group, path: "source-group-with-members_#{SecureRandom.hex(8)}") }
      let(:target_group_with_project) { create(:group, path: "target-group-with-project_#{SecureRandom.hex(8)}") }

      let!(:project) { create(:project, :with_readme, group: target_group_with_project) }

      let(:maintainer_user) { Runtime::User::Store.additional_test_user }

      before do
        source_group_with_members.add_member(maintainer_user, Resource::Members::AccessLevel::MAINTAINER)
      end

      it 'can be shared with another group with correct access level',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347935' do
        Flow::Login.sign_in

        target_group_with_project.visit!

        Page::Group::Menu.perform(&:go_to_members)
        Page::Group::Members.perform do |members|
          members.invite_group(source_group_with_members.path)

          expect(members).to have_group(source_group_with_members.path)
        end

        Page::Main::Menu.perform(&:sign_out)
        Flow::Login.sign_in(as: maintainer_user)

        Page::Dashboard::Projects.perform do |projects|
          projects.click_member_tab
          expect(projects).to have_filtered_project_with_access_role(project.name, "Guest")
        end
      end
    end
  end
end
