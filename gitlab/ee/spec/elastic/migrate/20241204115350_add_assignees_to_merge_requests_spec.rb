# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241204115350_add_assignees_to_merge_requests.rb')

RSpec.describe AddAssigneesToMergeRequests, feature_category: :global_search do
  let(:version) { 20241204115350 }

  describe 'migration', :elastic, :sidekiq_inline do
    include_examples 'migration adds mapping'
  end
end
