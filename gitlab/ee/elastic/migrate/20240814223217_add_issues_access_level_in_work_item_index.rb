# frozen_string_literal: true

class AddIssuesAccessLevelInWorkItemIndex < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  private

  def index_name
    ::Search::Elastic::References::WorkItem.index
  end

  def new_mappings
    {
      issues_access_level: {
        type: 'short'
      }
    }
  end
end

AddIssuesAccessLevelInWorkItemIndex.prepend ::Elastic::MigrationObsolete
