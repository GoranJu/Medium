# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250204111501_reindex_users_to_update_integer_with_long_type.rb')

RSpec.describe ReindexUsersToUpdateIntegerWithLongType, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20250204111501 }

  include_examples 'migration reindex based on schema_version' do
    let(:objects) { create_list(:user, 3) }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 9_000 }
  end
end
