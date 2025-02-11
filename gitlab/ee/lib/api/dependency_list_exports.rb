# frozen_string_literal: true

module API
  class DependencyListExports < ::API::Base
    feature_category :dependency_management
    urgency :low

    before do
      authenticate!
    end

    helpers do
      def find_export
        ::Dependencies::DependencyListExport.find_by_id(params[:export_id].to_i)
      end

      def present_created_export(result)
        if result.success?
          present result.payload[:dependency_list_export], with: EE::API::Entities::DependencyListExport
        else
          render_api_error!(result.message, :unprocessable_entity)
        end
      end
    end

    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      params do
        requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'

        optional :send_email, type: Boolean, default: false, desc: 'Send an email when the export completes'
      end
      desc 'Generate a dependency list export on a project-level'
      post ':id/dependency_list_exports' do
        authorize! :read_dependency, user_project

        result = ::Dependencies::CreateExportService.new(user_project, current_user, params).execute

        present_created_export(result)
      end
    end

    resource :groups, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      params do
        requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the group'

        optional :send_email, type: Boolean, default: false, desc: 'Send an email when the export completes'
      end
      desc 'Generate a dependency list export on a group-level'
      post ':id/dependency_list_exports' do
        authorize! :read_dependency, user_group

        params[:export_type] = :json_array

        result = ::Dependencies::CreateExportService.new(user_group, current_user, params).execute

        present_created_export(result)
      end
    end

    resource :organizations do
      params do
        requires :id, types: [String, Integer], desc: 'The ID of the organization'

        optional :send_email, type: Boolean, default: false, desc: 'Send an email when the export completes'
      end
      desc 'Generate a dependency list export on an organization-level'
      post ':id/dependency_list_exports' do
        not_found! unless Feature.enabled?(:explore_dependencies, current_user)

        organization = find_organization!(params[:id])
        authorize! :read_dependency, organization

        params[:export_type] = :csv

        result = ::Dependencies::CreateExportService
          .new(organization, current_user, params)
          .execute

        present_created_export(result)
      end
    end

    resource :pipelines do
      params do
        requires :id, types: [String, Integer], desc: 'The ID of the pipeline'

        optional :export_type, type: String, values: %w[sbom dependency_list], desc: 'The type of the export file'
        optional :send_email, type: Boolean, default: false, desc: 'Send an email when the export completes'
      end
      desc 'Generate a dependency list export on a pipeline-level'
      post ':id/dependency_list_exports' do
        # Currently, we only support sbom export type for this endpoint.
        not_found! if params[:export_type] != 'sbom'

        authorize! :read_dependency, user_pipeline

        result = ::Dependencies::CreateExportService.new(
          user_pipeline, current_user, params).execute

        present_created_export(result)
      end
    end

    params do
      requires :export_id, types: [Integer, String], desc: 'The ID of the dependency list export'
    end
    desc 'Get a dependency list export'
    get 'dependency_list_exports/:export_id' do
      dependency_list_export = find_export

      authorize! :read_dependency_list_export, dependency_list_export

      if dependency_list_export&.finished?
        present dependency_list_export, with: EE::API::Entities::DependencyListExport
      else
        ::Gitlab::PollingInterval.set_api_header(self, interval: 5_000)
        status :accepted
      end
    end

    desc 'Download a dependency list export'
    get 'dependency_list_exports/:export_id/download' do
      dependency_list_export = find_export

      authorize! :read_dependency_list_export, dependency_list_export

      if dependency_list_export&.finished?
        present_carrierwave_file!(dependency_list_export.file)
      else
        not_found!('DependencyListExport')
      end
    end
  end
end
