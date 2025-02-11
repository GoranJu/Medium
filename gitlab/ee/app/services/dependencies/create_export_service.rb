# frozen_string_literal: true

module Dependencies
  class CreateExportService
    ALLOWED_PARAMS = %i[
      export_type
      send_email
    ].freeze

    def initialize(exportable, author, params)
      @exportable = exportable
      @author = author
      @params = params
    end

    attr_reader :author, :exportable, :params

    def execute
      dependency_list_export = create_export

      if dependency_list_export.persisted?
        Dependencies::ExportWorker.perform_async(dependency_list_export.id)

        ServiceResponse.success(payload: { dependency_list_export: dependency_list_export })
      else
        ServiceResponse.error(message: dependency_list_export.errors.full_messages)
      end
    end

    private

    def create_export
      Dependencies::DependencyListExport.create(
        exportable: exportable,
        author: author,
        **create_params
      )
    end

    def create_params
      params.slice(*ALLOWED_PARAMS)
    end
  end
end
