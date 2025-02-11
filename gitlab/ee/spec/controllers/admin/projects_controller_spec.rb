# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::ProjectsController, :geo, feature_category: :groups_and_projects do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:role) { create(:admin_role, :read_admin_dashboard, user: user) }

  describe 'GET /projects' do
    subject(:get_admin_projects) { get :index }

    context 'when using custom permissions' do
      before do
        sign_in(user)
      end

      context 'when custom_roles feature is available' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'responds with success' do
          get_admin_projects

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when custom_roles feature is not available' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it 'responds with not found' do
          get_admin_projects

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe 'GET /projects/:id' do
    let_it_be(:project) { create(:project) }

    subject { get :show, params: { namespace_id: project.namespace.path, id: project.path } }

    render_views

    context 'for Geo' do
      include EE::GeoHelpers

      let_it_be(:primary) { create(:geo_node, :primary) }
      let_it_be(:secondary) { create(:geo_node, :secondary) }

      before do
        sign_in(admin)
      end

      context 'when Geo is enabled' do
        context 'on a primary site' do
          before do
            stub_current_geo_node(primary)
          end

          it 'does not display a different read-only message' do
            expect(subject).to have_gitlab_http_status(:ok)

            expect(subject.body).not_to match('You may be able to make a limited amount of changes or perform a limited amount of actions on this page')
            expect(subject.body).not_to include(primary.url)
          end
        end

        context 'on a secondary site' do
          before do
            stub_current_geo_node(secondary)
          end

          it 'displays a different read-only message based on skip_readonly_message' do
            expect(subject.body).to match('You may be able to make a limited amount of changes or perform a limited amount of actions on this page')
            expect(subject.body).to include(primary.url)
          end
        end
      end

      context 'without Geo enabled' do
        it 'does not display a different read-only message' do
          expect(subject).to have_gitlab_http_status(:ok)

          expect(subject.body).not_to match('You may be able to make a limited amount of changes or perform a limited amount of actions on this page')
          expect(subject.body).not_to include(primary.url)
        end
      end
    end

    context 'when using custom permissions' do
      before do
        sign_in(user)
      end

      context 'when custom_roles feature is available' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'responds with success' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when custom_roles feature is not available' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it 'responds with not found' do
          subject

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
