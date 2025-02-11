# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250203213829_reindex_projects_to_update_integer_with_long_type.rb')

RSpec.describe ReindexProjectsToUpdateIntegerWithLongType, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20250203213829 }

  include_examples 'migration reindex based on schema_version' do
    let(:objects) { create_list(:project, 3) }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 9_000 }
  end
end
