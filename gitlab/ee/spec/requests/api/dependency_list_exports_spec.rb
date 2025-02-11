# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::DependencyListExports, feature_category: :dependency_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let(:export_type) { nil }
  let(:send_email) { false }
  let(:params) { { export_type: export_type, send_email: send_email } }

  shared_examples_for 'creating dependency list export' do
    subject(:create_dependency_list_export) { post api(request_path, user), params: params }

    context 'with user without permission' do
      before do
        stub_licensed_features(dependency_scanning: true, security_dashboard: true)

        resource.add_guest(user)
      end

      it 'returns 403' do
        expect(::Dependencies::CreateExportService).not_to receive(:new)

        create_dependency_list_export

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'with user with enough permission' do
      before do
        resource.add_developer(user)
      end

      context 'with license feature disabled' do
        before do
          stub_licensed_features(dependency_scanning: false, security_dashboard: false)
        end

        it 'returns 403' do
          expect(::Dependencies::CreateExportService).not_to receive(:new)

          create_dependency_list_export

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with license feature enabled' do
        before do
          stub_licensed_features(dependency_scanning: true, security_dashboard: true)
        end

        it 'creates and returns a dependency_list_export' do
          create_dependency_list_export

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response).to have_key('id')
          expect(json_response).to have_key('has_finished')
          expect(json_response).to have_key('self')
          expect(json_response).to have_key('download')
          expect(json_response['export_type']).to eq(export_type)
          expect(json_response['send_email']).to eq(send_email)
        end

        context 'when send_email is true' do
          let(:send_email) { true }

          it 'sets value on created export' do
            create_dependency_list_export

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['send_email']).to eq(send_email)
          end
        end

        context 'when export creation fails' do
          before do
            allow_next_instance_of(Dependencies::CreateExportService) do |service|
              error = ServiceResponse.error(message: ['validation error'])
              allow(service).to receive(:execute).and_return(error)
            end
          end

          it 'returns and error message and status code from the service' do
            create_dependency_list_export

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
            expect(json_response['message']).to eq(['validation error'])
          end
        end
      end
    end
  end

  describe 'POST /organizations/:id/dependency_list_exports' do
    let_it_be(:organization) { create(:organization) }

    context 'when admin mode is enabled', :enable_admin_mode do
      context 'when the user is an admin' do
        let_it_be(:current_user) { create(:user, :admin) }

        before do
          stub_licensed_features(dependency_scanning: true, security_dashboard: true)
        end

        it 'generates an export' do
          post api("/organizations/#{organization.id}/dependency_list_exports", current_user)

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response).to be_present
          expect(json_response).to have_key('id')
          expect(json_response).to have_key('has_finished')
          expect(json_response).to have_key('self')
          expect(json_response).to have_key('download')

          created_export = ::Dependencies::DependencyListExport.find(json_response['id'])
          expect(created_export.export_type).to eq('csv')
        end

        context 'when the `explore_dependencies` feature flag is disabled' do
          before do
            stub_feature_flags(explore_dependencies: false)
          end

          it 'does not generate an export' do
            post api("/organizations/#{organization.id}/dependency_list_exports", current_user)

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end
  end

  describe 'POST /projects/:id/dependency_list_exports' do
    let(:request_path) { "/projects/#{project.id}/dependency_list_exports" }
    let(:resource) { project }
    let(:exportable) { project }
    let(:export_type) { 'dependency_list' }

    it_behaves_like 'creating dependency list export'
  end

  describe 'POST /groups/:id/dependency_list_exports' do
    let(:request_path) { "/groups/#{group.id}/dependency_list_exports" }
    let(:resource) { group }
    let(:exportable) { group }
    let(:export_type) { 'json_array' }

    it_behaves_like 'creating dependency list export'
  end

  describe 'POST /pipelines/:id/dependency_list_exports' do
    let(:request_path) { "/pipelines/#{pipeline.id}/dependency_list_exports" }
    let(:resource) { project }
    let(:exportable) { pipeline }
    let(:export_type) { 'sbom' }

    it_behaves_like 'creating dependency list export'
  end

  describe 'GET /dependency_list_exports/:export_id' do
    let(:dependency_list_export) { create(:dependency_list_export, :finished, author: user, project: project) }
    let(:request_path) { "/dependency_list_exports/#{dependency_list_export.id}" }

    subject(:fetch_dependency_list_export) { get api(request_path, user) }

    context 'with user without permission' do
      before do
        stub_licensed_features(dependency_scanning: true)
        project.add_guest(user)
      end

      it 'returns 403' do
        fetch_dependency_list_export

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'with user with enough permission' do
      before do
        project.add_developer(user)
      end

      context 'with license feature disabled' do
        before do
          stub_licensed_features(dependency_scanning: false)
        end

        it 'returns 403' do
          fetch_dependency_list_export

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with license feature enabled' do
        before do
          stub_licensed_features(dependency_scanning: true)
        end

        it 'fetches and returns a dependency_list_export' do
          fetch_dependency_list_export

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to have_key('id')
          expect(json_response).to have_key('has_finished')
          expect(json_response).to have_key('self')
          expect(json_response).to have_key('download')
        end

        context 'with dependency list export not finished' do
          let(:dependency_list_export) { create(:dependency_list_export, author: user, project: project) }

          it 'sets polling and returns accepted' do
            fetch_dependency_list_export

            expect(response).to have_gitlab_http_status(:accepted)
            expect(response.headers[Gitlab::PollingInterval::HEADER_NAME]).to match(/\d+/)
          end
        end
      end
    end
  end

  describe 'GET /dependency_list_exports/:export_id/download' do
    let(:dependency_list_export) { create(:dependency_list_export, :finished, author: user, project: project) }
    let(:request_path) { "/dependency_list_exports/#{dependency_list_export.id}/download" }

    subject(:download_dependency_list_export) { get api(request_path, user) }

    context 'with user without permission' do
      before do
        stub_licensed_features(dependency_scanning: true)
        project.add_guest(user)
      end

      it 'returns 403' do
        download_dependency_list_export

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'with user with enough permission' do
      before do
        project.add_developer(user)
      end

      context 'with license feature disabled' do
        before do
          stub_licensed_features(dependency_scanning: false)
        end

        it 'returns 403' do
          download_dependency_list_export

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with license feature enabled' do
        before do
          stub_licensed_features(dependency_scanning: true)
        end

        it 'returns file content' do
          download_dependency_list_export

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to have_key('report')
          expect(json_response).to have_key('dependencies')
        end

        context 'with dependency list export not finished' do
          let(:dependency_list_export) { create(:dependency_list_export, author: user, project: project) }

          it 'returns 404' do
            download_dependency_list_export

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end
  end
end
