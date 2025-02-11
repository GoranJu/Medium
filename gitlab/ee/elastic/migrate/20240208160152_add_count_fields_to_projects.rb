# frozen_string_literal: true

class AddCountFieldsToProjects < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  DOCUMENT_TYPE = Project

  private

  def new_mappings
    {
      star_count: {
        type: 'integer'
      },
      last_repository_updated_date: {
        type: 'date'
      }
    }
  end
end

AddCountFieldsToProjects.prepend ::Elastic::MigrationObsolete
