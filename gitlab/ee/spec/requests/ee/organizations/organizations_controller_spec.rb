# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::OrganizationsController, feature_category: :cell do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }
  let_it_be(:organization_owner) { create :organization_owner, organization: organization, user: user }

  before do
    sign_in(user)
  end

  describe 'GET #show' do
    subject(:gitlab_request) { get organization_path(organization) }

    it 'pushes adjournedDeletionForProjectsAndGroups licensed feature' do
      gitlab_request

      expect(response.body).to have_pushed_licensed_features(adjournedDeletionForProjectsAndGroups: false)
    end
  end

  describe 'GET #groups_and_projects' do
    subject(:gitlab_request) { get groups_and_projects_organization_path(organization) }

    it 'pushes adjournedDeletionForProjectsAndGroups licensed feature' do
      gitlab_request

      expect(response.body).to have_pushed_licensed_features(adjournedDeletionForProjectsAndGroups: false)
    end
  end
end
