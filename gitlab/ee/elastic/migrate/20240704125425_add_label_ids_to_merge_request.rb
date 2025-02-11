# frozen_string_literal: true

class AddLabelIdsToMergeRequest < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  DOCUMENT_TYPE = MergeRequest

  private

  def new_mappings
    { label_ids: { type: 'keyword' } }
  end
end

AddLabelIdsToMergeRequest.prepend ::Elastic::MigrationObsolete
