# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250113152652_reindex_wiki_to_update_analyzer_for_content.rb')

RSpec.describe ReindexWikiToUpdateAnalyzerForContent, feature_category: :global_search do
  let(:version) { 20250113152652 }
  let(:migration) { described_class.new(version) }

  it 'does not have migration options set', :aggregate_failures do
    expect(migration).not_to be_batched
    expect(migration).not_to be_retry_on_failure
  end

  describe '#migrate' do
    it 'creates reindexing task with correct target and options' do
      expect { migration.migrate }.to change { Search::Elastic::ReindexingTask.count }.by(1)
      task = Search::Elastic::ReindexingTask.last
      expect(task.targets).to eq(%w[Wiki])
      expect(task.options).to eq('skip_pending_migrations_check' => true)
    end
  end

  describe '#completed?' do
    it 'always returns true' do
      expect(migration.completed?).to be_truthy
    end
  end
end
