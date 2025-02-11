# frozen_string_literal: true

class AddAssigneesToMergeRequests < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  DOCUMENT_TYPE = MergeRequest

  private

  def new_mappings
    { assignee_ids: { type: 'keyword' } }
  end
end
