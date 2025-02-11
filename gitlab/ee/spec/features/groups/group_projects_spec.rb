# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group projects page', feature_category: :groups_and_projects do
  let(:user) { create :user }
  let(:group) { create :group }

  before do
    stub_feature_flags(new_project_creation_form: false)
    group.add_owner(user)

    sign_in(user)
  end

  context 'when group has project pending deletion' do
    before do
      stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
    end

    let!(:project) { create(:project, :archived, namespace: group, marked_for_deletion_at: Date.current) }

    it 'redirects to the groups overview page' do
      visit projects_group_path(group)

      expect(page).to have_current_path(group_path(group))
    end
  end
end
