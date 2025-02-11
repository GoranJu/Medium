# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241107144941_backfill_traversal_ids_on_merge_requests.rb')

RSpec.describe BackfillTraversalIdsOnMergeRequests, feature_category: :global_search do
  let(:version) { 20241107144941 }

  describe 'migration', :elastic_delete_by_query, :sidekiq_inline do
    include_examples 'migration backfills fields' do
      let(:expected_throttle_delay) { 1.minute }
      let(:expected_batch_size) { 9000 }
      let_it_be(:project) { create(:project) }
      let(:objects) do
        create_list(:merge_request, 3, :unique_branches, target_project: project, source_project: project)
      end

      let(:traversal_ids) { "#{project.namespace.id}-p#{project.id}-" }
      let(:expected_fields) do
        { traversal_ids: traversal_ids }
      end
    end
  end
end
