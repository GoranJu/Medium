# frozen_string_literal: true

class AddWorkItemTypeIdToIssues < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  private

  def index_name
    ::Elastic::Latest::IssueConfig.index_name
  end

  def new_mappings
    {
      work_item_type_id: {
        type: 'integer'
      }
    }
  end
end

AddWorkItemTypeIdToIssues.prepend ::Elastic::MigrationObsolete
