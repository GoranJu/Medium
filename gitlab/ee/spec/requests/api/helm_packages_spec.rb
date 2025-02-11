# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::HelmPackages, feature_category: :package_registry do
  include HttpBasicAuthHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: user) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:package) { create(:helm_package, project: project) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

  let(:headers) { basic_auth_header(user.username, personal_access_token.token) }

  describe 'GET /api/v4/projects/:id/packages/helm/:channel/charts/:file_name.tgz' do
    let(:url) { "/projects/#{project.id}/packages/helm/stable/charts/#{package.name}-#{package.version}.tgz" }

    subject { get api(url), headers: headers }

    it_behaves_like 'applying ip restriction for group'
  end
end
