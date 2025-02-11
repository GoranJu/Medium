# frozen_string_literal: true

class AddNotesToWorkItems < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  private

  def index_name
    ::Search::Elastic::References::WorkItem.index
  end

  def new_mappings
    {
      notes: {
        type: :text, index_options: 'positions', analyzer: :code_analyzer
      },
      notes_internal: {
        type: :text, index_options: 'positions', analyzer: :code_analyzer
      }
    }
  end
end

AddNotesToWorkItems.prepend ::Elastic::MigrationObsolete
