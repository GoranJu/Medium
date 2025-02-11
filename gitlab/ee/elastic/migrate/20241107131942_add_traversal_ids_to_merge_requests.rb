# frozen_string_literal: true

class AddTraversalIdsToMergeRequests < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  DOCUMENT_TYPE = MergeRequest

  private

  def new_mappings
    { traversal_ids: { type: 'keyword' } }
  end
end
