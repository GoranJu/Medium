# frozen_string_literal: true

class AddRoutingToIssues < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  DOCUMENT_TYPE = Issue

  private

  def new_mappings
    { routing: { type: 'keyword' } }
  end
end

AddRoutingToIssues.prepend ::Elastic::MigrationObsolete
